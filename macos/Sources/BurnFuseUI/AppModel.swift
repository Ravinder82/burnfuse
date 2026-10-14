import Foundation
import Combine

/// Owns the state file and keeps a live picture of it.
///
/// Deliberately GUI-free so the screenshot renderer and tests can drive it.
/// Everything the menu-bar UI does goes through here, and every mutation is
/// written straight back to ~/.burnfuse/state.json so the CLI sees it instantly.
@MainActor
public final class AppModel: ObservableObject {

    @Published public private(set) var state: AppState
    @Published public var errorMessage: String?
    @Published public var lastRefresh: Date = Date()
    @Published public var selectedKeyID: String?

    public var onIncident: ((Incident) -> Void)?

    public let stateURL: URL
    private var watcher: Timer?
    private var lastSeenFingerprint: String = ""

    public init(stateURL: URL? = nil, pollInterval: TimeInterval = 4) {
        self.stateURL = stateURL ?? AppModel.defaultStateURL()
        self.state = AppModel.read(from: self.stateURL)
        self.lastSeenFingerprint = fingerprint(of: self.state)
        startWatching(every: pollInterval)
    }

    public static func defaultStateURL() -> URL {
        if let override = ProcessInfo.processInfo.environment["BURNFUSE_STATE"] {
            return URL(fileURLWithPath: override)
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".burnfuse/state.json")
    }

    // MARK: - Disk

    static func read(from url: URL) -> AppState {
        guard let data = try? Data(contentsOf: url) else { return AppState() }
        let decoder = JSONDecoder()
        return (try? decoder.decode(AppState.self, from: data)) ?? AppState()
    }

    private func fingerprint(of state: AppState) -> String {
        "\(state.entries.count)-\(state.incidents.count)-" +
        state.entries.map { "\($0.id):\($0.lastReading):\($0.status):\($0.hourlyLimit):\($0.readings.count)" }.joined()
    }

    public func reloadFromDisk() {
        let fresh = AppModel.read(from: stateURL)
        let freshPrint = fingerprint(of: fresh)
        guard freshPrint != lastSeenFingerprint else {
            lastRefresh = Date()
            return
        }
        lastSeenFingerprint = freshPrint
        state = fresh
        lastRefresh = Date()
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(
                at: stateURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(state)
            try data.write(to: stateURL, options: .atomic)
            lastSeenFingerprint = fingerprint(of: state)
        } catch {
            errorMessage = "Could not save: \(error.localizedDescription)"
        }
    }

    private func startWatching(every interval: TimeInterval) {
        watcher?.invalidate()
        guard interval > 0 else { return }
        watcher = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.reloadFromDisk() }
        }
    }

    public func stopWatching() {
        watcher?.invalidate()
        watcher = nil
    }

    // MARK: - Queries

    public func assessment(for key: BurnKey) -> BurnEngine.Assessment {
        BurnEngine.assess(key, settings: state.settings)
    }

    public var assessments: [String: BurnEngine.Assessment] {
        Dictionary(uniqueKeysWithValues: state.entries.map { ($0.id, assessment(for: $0)) })
    }

    public var headline: String {
        if let t = state.tripped.first {
            return "\(t.name) tripped"
        }
        return Fmt.perHour(state.totalBurn)
    }

    public var statusSummary: String {
        if state.hasBreach {
            return "\(state.tripped.count) tripped"
        }
        if state.entries.isEmpty {
            return "No keys yet"
        }
        return "\(state.entries.count) armed"
    }

    // MARK: - Mutations

    public func record(keyID: String, cost: Double, model: String? = nil) {
        if let incident = BurnEngine.recordReading(&state, keyID: keyID, cost: cost, model: model) {
            onIncident?(incident)
        }
        persist()
    }

    public func setCap(keyID: String, cap: Double) {
        BurnEngine.setCap(&state, keyID: keyID, cap: cap)
        persist()
    }

    public func setAutoKill(keyID: String, enabled: Bool) {
        guard let index = state.entries.firstIndex(where: { $0.id == keyID }) else { return }
        state.entries[index].autoKill = enabled
        persist()
    }

    public func trip(keyID: String) {
        BurnEngine.trip(&state, keyID: keyID)
        if let incident = state.incidents.first {
            onIncident?(incident)
        }
        persist()
    }

    public func tripAll() {
        BurnEngine.tripAll(&state)
        if let incident = state.incidents.first { onIncident?(incident) }
        persist()
    }

    public func arm(keyID: String, clearHistory: Bool = false) {
        BurnEngine.arm(&state, keyID: keyID, clearHistory: clearHistory)
        persist()
    }

    public func armAll(clearHistory: Bool = false) {
        for key in state.entries { BurnEngine.arm(&state, keyID: key.id, clearHistory: clearHistory) }
        persist()
    }

    @discardableResult
    public func addKey(name: String, provider: String, cap: Double, spendUrl: String? = nil, jsonPath: String? = nil) -> BurnKey {
        var key = BurnEngine.addKey(&state, name: name, provider: provider, cap: cap)
        if spendUrl != nil || jsonPath != nil {
            key.source = KeySource(spendUrl: spendUrl, jsonPath: jsonPath)
            if let index = state.entries.firstIndex(where: { $0.id == key.id }) {
                state.entries[index].source = key.source
            }
        }
        persist()
        return key
    }

    public func remove(keyID: String) {
        BurnEngine.remove(&state, keyID: keyID)
        if selectedKeyID == keyID { selectedKeyID = nil }
        persist()
    }

    public func updateSettings(_ transform: (inout Settings) -> Void) {
        transform(&state.settings)
        persist()
    }

    public func clearIncidents() {
        state.incidents = []
        persist()
    }

    /// Seed a realistic spread so the app has something to show on first run.
    public func seedDemoData() {
        let now = Date().timeIntervalSince1970 * 1000
        func history(_ values: [Double]) -> [Reading] {
            values.enumerated().map { index, cost in
                Reading(at: now - Double(values.count - index) * 3_600_000, cost: cost)
            }
        }
        let seeds: [BurnKey] = [
            BurnKey(id: BurnEngine.makeID(seed: "OpenAI prod"), name: "OpenAI prod", provider: "openai",
                    hourlyLimit: 5, readings: history([1.12, 1.28, 1.19, 1.34, 1.22, 1.31]), lastReading: 1.31),
            BurnKey(id: BurnEngine.makeID(seed: "Claude batch"), name: "Claude batch", provider: "anthropic",
                    hourlyLimit: 8, readings: history([0.62, 0.58, 0.71, 0.66, 0.69, 0.63]), lastReading: 0.63),
            BurnKey(id: BurnEngine.makeID(seed: "Fal images"), name: "Fal images", provider: "custom",
                    hourlyLimit: 3, readings: history([0.4, 0.5, 0.45, 0.52, 0.48, 0.51]), lastReading: 0.51),
        ]
        for key in seeds where !state.entries.contains(where: { $0.name == key.name }) {
            state.entries.append(key)
        }
        persist()
    }
}
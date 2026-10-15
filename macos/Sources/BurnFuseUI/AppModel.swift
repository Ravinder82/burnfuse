import Foundation
import Combine

/// What the last connection test for a provider had to say.
///
/// A test is a read and nothing more: it never records a reading, so pressing
/// it cannot change what the app thinks a key is spending.
public enum KeyTest: Equatable, Sendable {
    case testing
    case working(String)
    case failed(String)

    public var isWorking: Bool {
        if case .working = self { return true }
        return false
    }

    public var isTesting: Bool {
        if case .testing = self { return true }
        return false
    }
}

/// What the last live read had to say about one key, and whether it was a
/// failure. The row shows the message either way, and offers the manual way out
/// only when the read actually failed — a success has nothing to escape from.
public struct KeyReadNote: Sendable, Equatable {
    public var message: String
    public var failed: Bool

    public init(message: String, failed: Bool) {
        self.message = message
        self.failed = failed
    }
}

/// Owns the state file and keeps a live picture of it.
///
/// Deliberately GUI-free so the screenshot renderer and tests can drive it.
/// Everything the menu-bar UI does goes through here, and every mutation is
/// written straight back to ~/.burnfuse/state.json — one readable file, on
/// your Mac, that is the whole product.
@MainActor
public final class AppModel: ObservableObject {

    @Published public private(set) var state: AppState
    @Published public var errorMessage: String?
    @Published public var lastRefresh: Date = Date()
    @Published public var selectedKeyID: String?

    /// Set while a live spend read is in flight, so buttons can show progress.
    @Published public var isRefreshing: Bool = false
    /// The last thing a live read had to say — success or reason it could not.
    @Published public var lastReadMessage: String?
    /// The same, per key, so a row can say what happened to *it* rather than
    /// making someone read a combined line and work out which key it was about —
    /// and so a row that failed can offer the way out in place.
    @Published public var lastMessageByKey: [String: KeyReadNote] = [:]
    /// Progress toward the next automatic live read, 0...1.
    @Published public var pollProgress: Double = 0
    /// The last Test result per provider. A key that cannot work says why here,
    /// now, instead of leaving the user to wait a minute and read a status line.
    @Published public var keyTests: [String: KeyTest] = [:]

    // MARK: - Switching a key off at the provider

    /// Which watched key's switch-off panel is open, if any. Anchored to the
    /// row it was opened from, so the explanation appears exactly where it was
    /// asked for. Opened from that row in Settings, and from the breach banner
    /// when the tripped key's provider is one BurnFuse can act on.
    @Published public var switchOffKeyID: String?
    /// The account's keys, as the provider last listed them.
    @Published public var accountKeys: [String: [Revoke.AccountKey]] = [:]
    /// What the last listing had to say — the provider's refusal, in its own
    /// terms, or an empty line when all is well.
    @Published public var accountKeysMessage: [String: String] = [:]
    /// Providers whose key list is being fetched right now.
    @Published public var listingAccountKeys: Set<String> = []
    /// The account key currently being switched off, so one row shows progress
    /// and the rest are held back.
    @Published public var switchingOffKeyID: String?
    /// What the provider said after the last switch-off. Success or refusal, and
    /// never a guess.
    @Published public var switchOffOutcome: Revoke.Outcome?

    /// The spend ceiling the provider itself enforces, per watched key, where it
    /// publishes one. The answer to "can this key still spend?" that does not
    /// need anyone's help.
    @Published public var keyLimits: [String: SpendSource.CreditLimit] = [:]

    public var onIncident: ((Incident) -> Void)?

    public let stateURL: URL
    private var watcher: Timer?
    private var lastSeenFingerprint: String = ""
    private var pollTimer: Timer?
    private var pollTick: Timer?
    private var pollSeconds: TimeInterval = 0

    /// Injectable clock, so the rate maths can be shown to work without waiting
    /// an hour to find out.
    public var clock: () -> Date = { Date() }

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

    // MARK: - Live polling

    /// How often we read live spend. Zero turns automatic reads off.
    public var refreshInterval: TimeInterval {
        get { pollSeconds }
        set { pollSeconds = max(0, newValue); schedulePolling() }
    }

    private func schedulePolling() {
        pollTimer?.invalidate()
        pollTick?.invalidate()
        pollTimer = nil
        pollTick = nil
        pollProgress = 0
        guard pollSeconds > 0 else { return }

        pollTimer = Timer.scheduledTimer(withTimeInterval: pollSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refreshLive() }
        }
        pollTick = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.pollSeconds > 0 else { return }
                let elapsed = Date().timeIntervalSince(self.lastLiveRead ?? self.lastRefresh)
                self.pollProgress = min(max(elapsed / self.pollSeconds, 0), 1)
            }
        }
    }

    private var lastLiveRead: Date?

    /// Read live spend for every key that supports it, then record what we
    /// learned.
    ///
    /// Providers that report a running total rather than a rate need two reads:
    /// the first saves a baseline and records nothing, the next one turns the
    /// difference into an hourly figure the engine can compare against a cap.
    public func refreshLive(session: URLSession = .shared) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false; lastLiveRead = Date(); pollProgress = 0 }

        var messages: [String] = []
        var byKey: [String: KeyReadNote] = [:]
        for key in state.entries where key.armed && !key.isTripped {
            guard SpendSource.canReadLive(key) else { continue }
            let resolution = Credentials.resolve(for: key.provider)
            let result = await SpendPoller.fetch(key, apiKey: resolution.key, session: session)
            guard result.ok, let figure = result.cost else {
                // When there was nothing to send, the provider never saw the
                // request — so its "invalid key" answer would be about a key it
                // was never given. Say what actually stopped the read instead.
                let message = resolution.key == nil
                    ? SpendPoller.missingKeyMessage(for: key, source: resolution.source)
                    : result.message
                messages.append("\(key.name): \(message)")
                byKey[key.id] = KeyReadNote(message: message, failed: true)
                continue
            }

            if SpendSource.measuresTotal(key) {
                let line = absorb(keyID: key.id, total: figure)
                messages.append(line)
                let note = line.replacingOccurrences(of: "\(key.name): ", with: "")
                byKey[key.id] = KeyReadNote(message: note, failed: false)
            } else {
                record(keyID: key.id, cost: figure)
                messages.append("\(key.name): \(Fmt.perHour(figure))")
                byKey[key.id] = KeyReadNote(message: "Read \(Fmt.perHour(figure)) a moment ago.", failed: false)
            }
            // A provider cap, when the provider publishes one. Kept even after
            // later failures: the ceiling does not stop existing because a read
            // failed, and it is exactly the moment a person wants to know it.
            if let limit = result.limit {
                keyLimits[key.id] = limit
            }
        }

        lastRefresh = Date()
        lastMessageByKey = byKey
        lastReadMessage = messages.isEmpty
            ? (state.entries.contains { !$0.isManualRead && Providers.canReadLive($0.provider) }
               ? "Nothing was read this pass."
               : "No key is set up for a live read yet. Type your spend instead.")
            : messages.prefix(3).joined(separator: "\n")
    }

    // MARK: - Switching a key off at the provider

    /// Open (or close) a key's switch-off panel. Nothing is fetched here — the
    /// panel asks when it appears, so a screen that never opens it never spends
    /// a request.
    public func showSwitchOffPanel(keyID: String?) {
        switchOffKeyID = keyID
        switchOffOutcome = nil
        guard let keyID,
              let provider = state.entries.first(where: { $0.id == keyID })?.provider else { return }
        accountKeysMessage[provider] = nil
    }

    /// Ask the provider for the keys on this account.
    ///
    /// Only asked where the app holds a credential that is allowed to ask. Where
    /// it is not — an ordinary OpenRouter key, say — the panel says why and
    /// shows where the switching really happens, rather than failing with the
    /// provider's 403 and leaving it there.
    public func loadAccountKeys(_ providerID: String, session: URLSession = .shared) async {
        guard Revoke.ability(for: providerID).canSwitchOff else {
            accountKeysMessage[providerID] = Revoke.explainer(for: providerID)
            accountKeys[providerID] = nil
            return
        }
        guard !listingAccountKeys.contains(providerID) else { return }
        listingAccountKeys.insert(providerID)
        defer { listingAccountKeys.remove(providerID) }

        let resolution = Credentials.resolve(for: providerID)
        let result = await Revoke.list(providerID: providerID, apiKey: resolution.key, session: session)
        if result.ok { accountKeys[providerID] = result.keys }
        accountKeysMessage[providerID] = result.message.isEmpty ? nil : result.message
    }

    /// Switch one key off, and report exactly what the provider said.
    ///
    /// After a success the rows are re-read straight away, because a key that no
    /// longer exists must not keep showing the spend it had a minute ago. If the
    /// key switched off was the one BurnFuse reads with, the read that follows
    /// fails — and the row says so, which is the truth.
    public func switchOff(_ accountKey: Revoke.AccountKey, providerID: String,
                          session: URLSession = .shared) async {
        guard switchingOffKeyID == nil else { return }
        switchingOffKeyID = accountKey.id
        switchOffOutcome = nil
        defer { switchingOffKeyID = nil }

        let resolution = Credentials.resolve(for: providerID)
        let outcome = await Revoke.switchOff(providerID: providerID, key: accountKey,
                                             apiKey: resolution.key, session: session)
        switchOffOutcome = outcome
        guard outcome.ok else { return }

        accountKeys[providerID]?.removeAll { $0.id == accountKey.id }

        // Say plainly when the key that was just switched off is the one the
        // readings come from. The next read will confirm it; this is so the
        // person is told now, in the place they are looking.
        if Revoke.isTheKeyBurnFuseUses(accountKey, localKey: resolution.key) {
            let label = Providers.label(for: providerID)
            for key in state.entries where key.provider == providerID {
                lastMessageByKey[key.id] = KeyReadNote(
                    message: "The \(label) key BurnFuse was reading with has just been switched off. Paste a new Admin key to start reading \(label) again.",
                    failed: true
                )
            }
        }

        await refreshLive(session: session)
    }

    /// Store a provider's running total against a key, and record an hourly
    /// rate as soon as there are two to compare. Returns the line the user
    /// should see for this key.
    @discardableResult
    private func absorb(keyID: String, total: Double) -> String {
        guard let index = state.entries.firstIndex(where: { $0.id == keyID }) else { return "" }
        let name = state.entries[index].name
        let nowMs = clock().timeIntervalSince1970 * 1000
        let rate = state.entries[index].burnRate(fromCumulative: total, at: nowMs)

        state.entries[index].lastCumulative = total
        state.entries[index].lastCumulativeAt = nowMs
        persist()

        switch rate {
        case .hours(let hourly):
            record(keyID: keyID, cost: hourly)
            return "\(name): \(Fmt.perHour(hourly))"
        case .rebased:
            // A billing day rolled over mid-session. Re-baseline rather than
            // record a negative rate.
            return "\(name): its counter reset — first rate comes on the next check"
        case .unmeasured:
            return "\(name): baseline saved — first rate comes on the next check"
        }
    }

    // MARK: - Connection test

    /// Try a provider's key right now and say what happened.
    ///
    /// This is the answer to "I added my key and nothing happened": rather than
    /// waiting for the next poll and reading a status line, the user presses
    /// Test and gets the provider's own verdict, with the reason attached when
    /// there is one. It reads, and only reads — nothing is recorded, so a test
    /// can never move a burn figure.
    ///
    /// - Parameter draft: a key the user has typed but not saved yet. Someone
    ///   who pastes a key and presses Test plainly means "try this one", so the
    ///   field is honoured ahead of the store — still without storing anything.
    public func testCredential(_ providerID: String, using draft: String = "", session: URLSession = .shared) async {
        let typed = Credentials.sanitize(draft)
        let apiKey = typed ?? Credentials.key(for: providerID)
        var probe = BurnKey(id: "test-\(providerID)", name: Providers.label(for: providerID), provider: providerID)

        if providerID == "custom" {
            // A custom endpoint's address lives on the watched key rather than
            // on the provider, so borrow the first one that has a URL.
            guard let entry = state.entries.first(where: { entry in
                entry.provider == "custom"
                    && !(entry.source?.spendUrl?.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
            }) else {
                keyTests[providerID] = .failed("Add your endpoint's address first, then test it.")
                return
            }
            probe.source = entry.source
        } else if apiKey == nil {
            keyTests[providerID] = .failed(
                SpendPoller.missingKeyMessage(for: probe, source: Credentials.source(for: providerID))
            )
            return
        }

        guard SpendSource.canReadLive(probe) else {
            keyTests[providerID] = .failed("\(Providers.label(for: providerID)) has no spend read to test — its numbers are typed in.")
            return
        }

        keyTests[providerID] = .testing
        let result = await SpendPoller.fetch(probe, apiKey: apiKey, session: session)
        guard result.ok, let figure = result.cost else {
            keyTests[providerID] = .failed(result.message)
            return
        }

        keyTests[providerID] = .working(
            SpendSource.measuresTotal(probe)
                ? "Works. Read a running total of \(Fmt.money(figure))."
                : "Works. Read \(Fmt.perHour(figure))."
        )
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

    /// How close the fleet is to its combined cap, 0...1. Zero when no caps are
    /// set — the menu-bar colour leans on this, so it never divides by nothing.
    public var burnFraction: Double {
        guard state.totalCap > 0 else { return 0 }
        return min(max(state.totalBurn / state.totalCap, 0), 1)
    }

    // MARK: - Mutations

    public func record(keyID: String, cost: Double, model: String? = nil) {
        if let incident = BurnEngine.recordReading(&state, keyID: keyID, cost: cost, model: model) {
            // Pausing on a trip stops BurnFuse reading the key — nothing more.
            // It cannot stop the provider billing, and the interface says so
            // rather than implying this is protection it is not.
            if let index = state.entries.firstIndex(where: { $0.id == keyID }),
               BurnEngine.shouldPauseOnTrip(state.entries[index], settings: state.settings) {
                state.entries[index].armed = false
            }
            onIncident?(incident)
            sendWebhook(for: incident)
        }
        persist()
    }

    private func sendWebhook(for incident: Incident) {
        let webhook = state.settings.notifyWebhook
        guard !webhook.isEmpty else { return }
        let provider = state.entries.first(where: { $0.id == incident.entryId })?.provider ?? "custom"
        let text = "⛔ burnfuse tripped \(incident.name) — \(Fmt.perHour(incident.reading)) vs \(Fmt.money(incident.hourlyLimit)) cap (\(incident.reason)). \(Providers.revokeHint(for: provider))"
        Task { await SpendPoller.notify(webhook: webhook, text: text) }
    }

    /// Point a key at a custom cost endpoint. An empty string clears that
    /// field; nil leaves whatever is already there alone.
    public func setSource(keyID: String, spendUrl: String?, jsonPath: String?, header: String? = nil, measures: String? = nil) {
        guard let index = state.entries.firstIndex(where: { $0.id == keyID }) else { return }
        var source = state.entries[index].source ?? KeySource()

        if let spendUrl { source.spendUrl = emptyToNil(spendUrl) }
        if let jsonPath { source.jsonPath = emptyToNil(jsonPath) }
        if let header { source.header = emptyToNil(header) }
        if let measures { source.measures = emptyToNil(measures) }

        state.entries[index].source = source.isEmpty ? nil : source
        persist()
    }

    private func emptyToNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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
    public func addKey(
        name: String,
        provider: String,
        cap: Double,
        category: Category? = nil,
        readMode: ReadMode? = nil,
        spendUrl: String? = nil,
        jsonPath: String? = nil,
        header: String? = nil,
        measures: String? = nil
    ) -> BurnKey {
        var key = BurnEngine.addKey(&state, name: name, provider: provider, cap: cap,
                                    category: category, readMode: readMode)
        let source = KeySource(spendUrl: spendUrl, jsonPath: jsonPath, header: header, measures: measures)
        if !source.isEmpty {
            key.source = source
            if let index = state.entries.firstIndex(where: { $0.id == key.id }) {
                state.entries[index].source = source
            }
        }
        persist()
        return key
    }

    /// Rename a watched key. The id — and every reading and trip attached to it
    /// — stays put, so this is a label change and nothing else.
    public func rename(keyID: String, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = state.entries.firstIndex(where: { $0.id == keyID }) else { return }
        state.entries[index].name = trimmed
        persist()
    }

    public func setCategory(keyID: String, category: Category) {
        guard let index = state.entries.firstIndex(where: { $0.id == keyID }) else { return }
        state.entries[index].category = category
        persist()
    }

    /// Move a key between "BurnFuse reads it" and "I type it".
    ///
    /// Both directions are offered in the interface: a provider with no cost
    /// endpoint is manual from the start, and a live key whose provider turned
    /// it down becomes manual the moment the person chooses to type the number
    /// rather than chase a different key.
    public func setReadMode(keyID: String, mode: ReadMode) {
        guard let index = state.entries.firstIndex(where: { $0.id == keyID }) else { return }
        state.entries[index].readMode = mode == .auto ? nil : mode
        // The last verdict was about the way the key used to be read. Keeping it
        // would leave a failure line sitting on a row that no longer reads.
        lastMessageByKey[keyID] = nil
        persist()
    }

    public func remove(keyID: String) {
        BurnEngine.remove(&state, keyID: keyID)
        lastMessageByKey[keyID] = nil
        if selectedKeyID == keyID { selectedKeyID = nil }
        persist()
    }

    /// Store (or, with nil, clear) the key BurnFuse reads a provider with.
    public func storeCredential(_ value: String?, for providerID: String) {
        Credentials.set(value, for: providerID)
        // A different key means the last verdict was about a key that is gone.
        keyTests[providerID] = nil
        // …and a different key may mean a different account: the list of keys
        // the last one could see is not this key's to show.
        accountKeys[providerID] = nil
        accountKeysMessage[providerID] = nil
        if let keyID = switchOffKeyID,
           state.entries.first(where: { $0.id == keyID })?.provider == providerID {
            switchOffOutcome = nil
        }
    }

    /// Did the last live read of this key come back turned down?
    ///
    /// A key that cannot be read is not a calm key: BurnFuse has no figure for
    /// it at all. The row says so in words rather than showing a zero, and
    /// offers the manual way out while it is at it.
    public func lastReadFailed(_ keyID: String) -> Bool {
        lastMessageByKey[keyID]?.failed == true
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
            BurnKey(id: BurnEngine.makeID(seed: "Fal images"), name: "Fal images", provider: "fal",
                    hourlyLimit: 3, readings: history([0.4, 0.5, 0.45, 0.52, 0.48, 0.51]), lastReading: 0.51),
        ]
        for key in seeds where !state.entries.contains(where: { $0.name == key.name }) {
            state.entries.append(key)
        }
        persist()
    }
}
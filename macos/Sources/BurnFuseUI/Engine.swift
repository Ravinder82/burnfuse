import Foundation

/// The burn-rate math. Deliberately small and explainable, and pinned by tests
/// so the app's verdicts never drift.
/// Pure functions in, state out — no I/O, trivially testable.
public enum BurnEngine {

    public struct Assessment: Sendable, Equatable {
        public var baseline: Double
        public var sigma: Double
        public var current: Double
        public var z: Double
        public var zThreshold: Double
        public var overCap: Bool
        public var spike: Bool
        public var samples: Int
        public var hourlyLimit: Double

        public var breach: Bool { overCap || spike }
        public var reason: String? {
            guard breach else { return nil }
            return overCap ? "over cap" : "spike"
        }
    }

    public static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    public static func stdDev(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let m = mean(values)
        let variance = values.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(values.count)
        return variance.squareRoot()
    }

    public static func assess(_ key: BurnKey, settings: Settings) -> Assessment {
        let window = max(1, settings.historyWindow)
        let history = key.readings.suffix(window).map(\.cost)
        let current = key.lastReading
        let baseline = mean(history)
        let sigma = max(stdDev(history), settings.minStdDev)
        let z = history.isEmpty ? 0 : (current - baseline) / sigma
        let overCap = current > key.hourlyLimit
        let spike = !history.isEmpty && z >= settings.zThreshold
        return Assessment(
            baseline: baseline,
            sigma: sigma,
            current: current,
            z: z,
            zThreshold: settings.zThreshold,
            overCap: overCap,
            spike: spike,
            samples: history.count,
            hourlyLimit: key.hourlyLimit
        )
    }

    /// Combined burn across every key, oldest first, for the overview sparkline.
    public static func combinedSeries(_ state: AppState, window: Int = 24) -> [Double] {
        guard !state.entries.isEmpty else { return [] }
        let depth = min(window, state.entries.map(\.readings.count).max() ?? 0)
        guard depth > 0 else { return [] }
        return (0..<depth).map { offset in
            let index = depth - 1 - offset
            return state.entries.reduce(0.0) { total, key in
                let reversed = Array(key.readings.reversed())
                guard index < reversed.count else { return total }
                return total + reversed[index].cost
            }
        }
    }

    // MARK: - Mutations (pure)

    @discardableResult
    public static func recordReading(_ state: inout AppState, keyID: String, cost: Double, model: String? = nil) -> Incident? {
        guard let index = state.entries.firstIndex(where: { $0.id == keyID }) else { return nil }
        state.entries[index].readings.append(Reading(at: Date().timeIntervalSince1970 * 1000, cost: cost, model: model))
        if state.entries[index].readings.count > 500 {
            state.entries[index].readings.removeFirst(state.entries[index].readings.count - 500)
        }
        state.entries[index].lastReading = cost

        let assessment = assess(state.entries[index], settings: state.settings)
        guard assessment.breach, !state.entries[index].isTripped else { return nil }

        state.entries[index].status = "tripped"
        state.entries[index].trippedAt = Date().timeIntervalSince1970 * 1000
        let incident = Incident(
            entryId: state.entries[index].id,
            name: state.entries[index].name,
            reading: cost,
            hourlyLimit: state.entries[index].hourlyLimit,
            z: (assessment.z * 100).rounded() / 100,
            reason: assessment.reason ?? "break",
            action: "tripped"
        )
        state.incidents.insert(incident, at: 0)
        if state.incidents.count > 200 { state.incidents.removeLast(state.incidents.count - 200) }
        return incident
    }

    public static func setCap(_ state: inout AppState, keyID: String, cap: Double) {
        guard let index = state.entries.firstIndex(where: { $0.id == keyID }) else { return }
        state.entries[index].hourlyLimit = cap
    }

    public static func trip(_ state: inout AppState, keyID: String) {
        guard let index = state.entries.firstIndex(where: { $0.id == keyID }) else { return }
        state.entries[index].status = "tripped"
        state.entries[index].armed = false
        state.entries[index].trippedAt = Date().timeIntervalSince1970 * 1000
        let incident = Incident(
            entryId: state.entries[index].id,
            name: state.entries[index].name,
            reading: state.entries[index].lastReading,
            hourlyLimit: state.entries[index].hourlyLimit,
            z: 0,
            reason: "manual",
            action: "tripped"
        )
        state.incidents.insert(incident, at: 0)
    }

    public static func tripAll(_ state: inout AppState) {
        for key in state.entries { trip(&state, keyID: key.id) }
    }

    public static func arm(_ state: inout AppState, keyID: String, clearHistory: Bool = false) {
        guard let index = state.entries.firstIndex(where: { $0.id == keyID }) else { return }
        state.entries[index].status = "armed"
        state.entries[index].armed = true
        state.entries[index].trippedAt = nil
        if clearHistory {
            state.entries[index].readings = []
            state.entries[index].lastReading = 0
        }
    }

    public static func addKey(_ state: inout AppState, name: String, provider: String, cap: Double) -> BurnKey {
        let key = BurnKey(
            id: makeID(seed: name),
            name: name,
            provider: provider,
            hourlyLimit: cap
        )
        state.entries.append(key)
        return key
    }

    public static func remove(_ state: inout AppState, keyID: String) {
        state.entries.removeAll { $0.id == keyID }
    }

    public static func makeID(seed: String) -> String {
        let slug = seed
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        let clipped = String(slug.prefix(28))
        let tail = String(UUID().uuidString.prefix(4)).lowercased()
        return "\(clipped.isEmpty ? "key" : clipped)_\(tail)"
    }

    // MARK: - Outcomes

    /// Hours of unattended burn we assume before you would have noticed a leak.
    /// Used only for a clearly-labelled "averted" estimate — never a promise.
    public static let exposureHours: Double = 4

    /// Spend that did not happen because the breaker cut a key.
    public static func averted(_ incident: Incident) -> Double {
        max(0, incident.reading * exposureHours)
    }

    public static func totalAverted(_ state: AppState) -> Double {
        state.incidents.reduce(0) { $0 + averted($1) }
    }
}
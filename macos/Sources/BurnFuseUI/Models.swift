import Foundation

// MARK: - Shared state shape
//
// BurnFuse keeps one readable file at ~/.burnfuse/state.json: the keys you
// watch, their readings, and every trip. It is the whole product's memory,
// and nothing in it ever leaves your Mac.

public struct Reading: Codable, Identifiable, Hashable, Sendable {
    public var at: Double
    public var cost: Double
    public var model: String?

    public var id: Double { at }
    public var date: Date { Date(timeIntervalSince1970: at / 1000) }

    public init(at: Double, cost: Double, model: String? = nil) {
        self.at = at
        self.cost = cost
        self.model = model
    }

    enum CodingKeys: String, CodingKey { case at, cost, model }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        at = try c.decodeIfPresent(Double.self, forKey: .at) ?? 0
        cost = try c.decodeIfPresent(Double.self, forKey: .cost) ?? 0
        model = try c.decodeIfPresent(String.self, forKey: .model)
    }
}

public struct KeySource: Codable, Hashable, Sendable {
    public var spendUrl: String?
    public var jsonPath: String?
    /// A request header to send the key under, for endpoints that do not want
    /// `Authorization: Bearer …`.
    public var header: String?
    /// "rate" when the endpoint already reports dollars per hour, or "total"
    /// when it counts money up and BurnFuse has to divide by the time between
    /// two reads.
    public var measures: String?

    public init(spendUrl: String? = nil, jsonPath: String? = nil, header: String? = nil, measures: String? = nil) {
        self.spendUrl = spendUrl
        self.jsonPath = jsonPath
        self.header = header
        self.measures = measures
    }

    /// True when nothing here configures a live read.
    public var isEmpty: Bool {
        [spendUrl, jsonPath, header, measures].allSatisfy { $0?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true }
    }
}

/// What a provider's latest running total says about the burn rate.
///
/// Both OpenAI and OpenRouter count money up rather than reporting a rate, so a
/// single read means nothing. Two reads a little apart give a clean number.
public enum BurnRate: Equatable, Sendable {
    /// The first read for this key, or two reads that landed in the same
    /// instant. Nothing to compare against yet.
    case unmeasured
    /// The provider's counter went backwards — a billing day rolled over — so
    /// the comparison would be meaningless.
    case rebased
    /// Dollars per hour.
    case hours(Double)
}

public struct BurnKey: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var provider: String
    public var hourlyLimit: Double
    public var armed: Bool
    /// Stop reading this key once it trips, instead of watching it come down.
    ///
    /// Off by default, and worth knowing why: pausing is not protection. It stops
    /// BurnFuse reading a figure, and does nothing whatever about the provider
    /// still billing. Left off, a tripped key keeps reporting, so a runaway that
    /// is still running looks like one.
    public var autoKill: Bool
    public var status: String            // armed | tripped | paused
    public var readings: [Reading]
    public var lastReading: Double
    public var trippedAt: Double?
    public var createdAt: Double
    public var source: KeySource?
    /// The last running total the provider reported, for providers that count
    /// money up. Kept so an hourly rate survives an app restart.
    public var lastCumulative: Double?
    public var lastCumulativeAt: Double?

    public var isTripped: Bool { status == "tripped" }
    public var isArmed: Bool { armed && !isTripped }

    /// Burn as a share of the hourly cap, clamped to 0...1 for progress bars.
    public var capFill: Double {
        guard hourlyLimit > 0 else { return 0 }
        return min(max(lastReading / hourlyLimit, 0), 1)
    }

    public var burnHistory: [Double] { readings.map(\.cost) }

    /// What a provider's latest running total says about the hourly rate.
    public func burnRate(fromCumulative total: Double, at nowMs: Double) -> BurnRate {
        guard let previous = lastCumulative, let previousAt = lastCumulativeAt,
              previousAt < nowMs else {
            return .unmeasured
        }

        let change = total - previous
        guard change >= 0 else { return .rebased }

        let hours = (nowMs - previousAt) / 3_600_000
        guard hours > 0 else { return .unmeasured }

        return .hours(change / hours)
    }

    public init(
        id: String,
        name: String,
        provider: String = "custom",
        hourlyLimit: Double = 5,
        armed: Bool = true,
        autoKill: Bool = false,
        status: String = "armed",
        readings: [Reading] = [],
        lastReading: Double = 0,
        trippedAt: Double? = nil,
        createdAt: Double = Date().timeIntervalSince1970 * 1000,
        source: KeySource? = nil,
        lastCumulative: Double? = nil,
        lastCumulativeAt: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.hourlyLimit = hourlyLimit
        self.armed = armed
        self.autoKill = autoKill
        self.status = status
        self.readings = readings
        self.lastReading = lastReading
        self.trippedAt = trippedAt
        self.createdAt = createdAt
        self.source = source
        self.lastCumulative = lastCumulative
        self.lastCumulativeAt = lastCumulativeAt
    }

    enum CodingKeys: String, CodingKey {
        case id, name, provider, hourlyLimit, armed, autoKill, status
        case readings, lastReading, trippedAt, createdAt, source
        case lastCumulative, lastCumulativeAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Untitled key"
        provider = try c.decodeIfPresent(String.self, forKey: .provider) ?? "custom"
        hourlyLimit = try c.decodeIfPresent(Double.self, forKey: .hourlyLimit) ?? 5
        armed = try c.decodeIfPresent(Bool.self, forKey: .armed) ?? true
        autoKill = try c.decodeIfPresent(Bool.self, forKey: .autoKill) ?? false
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "armed"
        readings = try c.decodeIfPresent([Reading].self, forKey: .readings) ?? []
        lastReading = try c.decodeIfPresent(Double.self, forKey: .lastReading) ?? 0
        trippedAt = try c.decodeIfPresent(Double.self, forKey: .trippedAt)
        createdAt = try c.decodeIfPresent(Double.self, forKey: .createdAt) ?? 0
        source = try c.decodeIfPresent(KeySource.self, forKey: .source)
        lastCumulative = try c.decodeIfPresent(Double.self, forKey: .lastCumulative)
        lastCumulativeAt = try c.decodeIfPresent(Double.self, forKey: .lastCumulativeAt)
    }
}

public struct Settings: Codable, Hashable, Sendable {
    public var zThreshold: Double
    public var minStdDev: Double
    /// The blanket version of a key's own pause-on-trip flag: stop reading keys
    /// that trip, until they are re-armed. Only reading — never billing.
    public var autoKillOnBreach: Bool
    public var notifyWebhook: String
    public var historyWindow: Int

    public init(
        zThreshold: Double = 2.5,
        minStdDev: Double = 0.1,
        autoKillOnBreach: Bool = false,
        notifyWebhook: String = "",
        historyWindow: Int = 24
    ) {
        self.zThreshold = zThreshold
        self.minStdDev = minStdDev
        self.autoKillOnBreach = autoKillOnBreach
        self.notifyWebhook = notifyWebhook
        self.historyWindow = historyWindow
    }

    enum CodingKeys: String, CodingKey {
        case zThreshold, minStdDev, autoKillOnBreach, notifyWebhook, historyWindow
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        zThreshold = try c.decodeIfPresent(Double.self, forKey: .zThreshold) ?? 2.5
        minStdDev = try c.decodeIfPresent(Double.self, forKey: .minStdDev) ?? 0.1
        autoKillOnBreach = try c.decodeIfPresent(Bool.self, forKey: .autoKillOnBreach) ?? false
        notifyWebhook = try c.decodeIfPresent(String.self, forKey: .notifyWebhook) ?? ""
        historyWindow = try c.decodeIfPresent(Int.self, forKey: .historyWindow) ?? 24
    }
}

public struct Incident: Codable, Identifiable, Hashable, Sendable {
    public var at: Double
    public var entryId: String
    public var name: String
    public var reading: Double
    public var hourlyLimit: Double
    public var z: Double
    public var reason: String             // over cap | spike | manual
    public var action: String

    public var id: Double { at }
    public var date: Date { Date(timeIntervalSince1970: at / 1000) }

    public init(
        at: Double = Date().timeIntervalSince1970 * 1000,
        entryId: String,
        name: String,
        reading: Double,
        hourlyLimit: Double,
        z: Double,
        reason: String,
        action: String
    ) {
        self.at = at
        self.entryId = entryId
        self.name = name
        self.reading = reading
        self.hourlyLimit = hourlyLimit
        self.z = z
        self.reason = reason
        self.action = action
    }

    enum CodingKeys: String, CodingKey {
        case at, entryId, name, reading, hourlyLimit, z, reason, action
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        at = try c.decodeIfPresent(Double.self, forKey: .at) ?? 0
        entryId = try c.decodeIfPresent(String.self, forKey: .entryId) ?? ""
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        reading = try c.decodeIfPresent(Double.self, forKey: .reading) ?? 0
        hourlyLimit = try c.decodeIfPresent(Double.self, forKey: .hourlyLimit) ?? 0
        z = try c.decodeIfPresent(Double.self, forKey: .z) ?? 0
        reason = try c.decodeIfPresent(String.self, forKey: .reason) ?? ""
        action = try c.decodeIfPresent(String.self, forKey: .action) ?? "tripped"
    }
}

public struct AppState: Codable, Sendable {
    public var version: Int
    public var settings: Settings
    public var entries: [BurnKey]
    public var incidents: [Incident]

    public init(
        version: Int = 2,
        settings: Settings = Settings(),
        entries: [BurnKey] = [],
        incidents: [Incident] = []
    ) {
        self.version = version
        self.settings = settings
        self.entries = entries
        self.incidents = incidents
    }

    enum CodingKeys: String, CodingKey { case version, settings, entries, incidents }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 2
        settings = try c.decodeIfPresent(Settings.self, forKey: .settings) ?? Settings()
        entries = try c.decodeIfPresent([BurnKey].self, forKey: .entries) ?? []
        incidents = try c.decodeIfPresent([Incident].self, forKey: .incidents) ?? []
    }

    // MARK: Derived

    public var tripped: [BurnKey] { entries.filter(\.isTripped) }
    public var totalBurn: Double { entries.reduce(0) { $0 + $1.lastReading } }
    public var totalCap: Double { entries.reduce(0) { $0 + $1.hourlyLimit } }
    public var hasBreach: Bool { !tripped.isEmpty }
}

public enum Fmt {
    public static func money(_ value: Double, digits: Int = 2) -> String {
        String(format: "$%.\(digits)f", value)
    }

    public static func perHour(_ value: Double) -> String {
        "\(money(value))/hr"
    }

    /// Money at the size it actually is: whole dollars once there are enough of
    /// them, cents while the number is still small. Rounding a real $0.40 down to
    /// "$0" reads as a bug, or worse, as a claim that nothing happened.
    public static func roughly(_ value: Double) -> String {
        value >= 10 ? money(value, digits: 0) : money(value, digits: 2)
    }

    public static func multiple(_ current: Double, _ baseline: Double) -> String {
        guard baseline > 0 else { return "—" }
        return String(format: "%.1f×", current / baseline)
    }
}
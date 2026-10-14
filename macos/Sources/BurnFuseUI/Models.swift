import Foundation

// MARK: - Shared state shape
//
// This mirrors ~/.burnfuse/state.json, which the CLI writes. One file, two
// front doors: `burnfuse` in the terminal and BurnFuse.app in the menu bar.
// Anything either tool writes shows up in the other within a couple seconds.

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
    public var killUrl: String?

    public init(spendUrl: String? = nil, jsonPath: String? = nil, killUrl: String? = nil) {
        self.spendUrl = spendUrl
        self.jsonPath = jsonPath
        self.killUrl = killUrl
    }
}

public struct BurnKey: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var provider: String
    public var hourlyLimit: Double
    public var armed: Bool
    public var autoKill: Bool
    public var status: String            // armed | tripped | paused
    public var readings: [Reading]
    public var lastReading: Double
    public var trippedAt: Double?
    public var createdAt: Double
    public var source: KeySource?

    public var isTripped: Bool { status == "tripped" }
    public var isArmed: Bool { armed && !isTripped }

    /// Burn as a share of the hourly cap, clamped to 0...1 for progress bars.
    public var capFill: Double {
        guard hourlyLimit > 0 else { return 0 }
        return min(max(lastReading / hourlyLimit, 0), 1)
    }

    public var burnHistory: [Double] { readings.map(\.cost) }

    public init(
        id: String,
        name: String,
        provider: String = "custom",
        hourlyLimit: Double = 5,
        armed: Bool = true,
        autoKill: Bool = true,
        status: String = "armed",
        readings: [Reading] = [],
        lastReading: Double = 0,
        trippedAt: Double? = nil,
        createdAt: Double = Date().timeIntervalSince1970 * 1000,
        source: KeySource? = nil
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
    }

    enum CodingKeys: String, CodingKey {
        case id, name, provider, hourlyLimit, armed, autoKill, status
        case readings, lastReading, trippedAt, createdAt, source
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Untitled key"
        provider = try c.decodeIfPresent(String.self, forKey: .provider) ?? "custom"
        hourlyLimit = try c.decodeIfPresent(Double.self, forKey: .hourlyLimit) ?? 5
        armed = try c.decodeIfPresent(Bool.self, forKey: .armed) ?? true
        autoKill = try c.decodeIfPresent(Bool.self, forKey: .autoKill) ?? true
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "armed"
        readings = try c.decodeIfPresent([Reading].self, forKey: .readings) ?? []
        lastReading = try c.decodeIfPresent(Double.self, forKey: .lastReading) ?? 0
        trippedAt = try c.decodeIfPresent(Double.self, forKey: .trippedAt)
        createdAt = try c.decodeIfPresent(Double.self, forKey: .createdAt) ?? 0
        source = try c.decodeIfPresent(KeySource.self, forKey: .source)
    }
}

public struct Settings: Codable, Hashable, Sendable {
    public var zThreshold: Double
    public var minStdDev: Double
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

    public static func sigma(_ z: Double) -> String {
        String(format: "%@%.2fσ", z >= 0 ? "+" : "", z)
    }

    public static func multiple(_ current: Double, _ baseline: Double) -> String {
        guard baseline > 0 else { return "—" }
        return String(format: "%.1f×", current / baseline)
    }
}
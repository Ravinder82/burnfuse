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

/// What a provider says this key used in tokens, over a window.
///
/// This is the *why* behind a dollar figure. Models do not cost the same per
/// token — they differ by orders of magnitude — so "this key is burning $9.90 an
/// hour" becomes actionable the moment it can be read next to "it is pushing 4
/// million tokens an hour".
///
/// Only some providers publish it, so it is optional everywhere it appears and
/// the screen names which providers the numbers came from. Nothing here is ever
/// derived: a provider that does not report tokens shows nothing, rather than a
/// figure the app made up from a price list.
public struct TokenUse: Codable, Hashable, Sendable {
    /// Input tokens for the window, cache reads included.
    public var input: Int
    /// Output tokens for the window.
    public var output: Int
    /// The part of `input` that was served from the provider's cache, where the
    /// provider says so. A subset of `input` — never added to it.
    public var cachedInput: Int?
    /// Model requests, where the provider counts them.
    public var requests: Int?
    /// The start of the window these numbers cover, in milliseconds since the
    /// epoch: a day, and the same day the hear-and-now spend figure covers.
    public var windowStart: Double
    /// When the read happened, so a figure that is a little behind can say so.
    public var at: Double

    public init(input: Int, output: Int, cachedInput: Int? = nil, requests: Int? = nil,
                windowStart: Double, at: Double = Date().timeIntervalSince1970 * 1000) {
        self.input = input
        self.output = output
        self.cachedInput = cachedInput
        self.requests = requests
        self.windowStart = windowStart
        self.at = at
    }

    public var total: Int { input + output }
    public var date: Date { Date(timeIntervalSince1970: at / 1000) }

    /// Is this reading from the day we are in? A figure from yesterday must
    /// never be shown under today's heading.
    public func isCurrent(now: Date = Date()) -> Bool {
        abs(TokenUse.dayStart(for: now) - windowStart) < 1
    }

    /// Midnight UTC, in milliseconds — the boundary the providers themselves
    /// bucket by.
    public static func dayStart(for date: Date) -> Double {
        (date.timeIntervalSince1970 / 86_400).rounded(.down) * 86_400 * 1000
    }
}

public struct KeySource: Codable, Hashable, Sendable {    public var spendUrl: String?
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

/// How a key's numbers get in.
///
/// `auto` means BurnFuse reads the provider. `manual` means the provider has no
/// readable spend — or turned the key down for it — and the figure comes from
/// the person watching. The second case is a real, first-class way to use the
/// app, not a failure state: some of the biggest providers simply do not publish
/// a cost endpoint, and saying so beats pretending otherwise.
public enum ReadMode: String, Codable, Sendable {
    case auto
    case manual
}

public struct BurnKey: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var provider: String
    /// What this key is for — how the watch list is grouped and how Overview
    /// adds spend up. Optional so older state files keep loading; when it is
    /// absent the provider decides.
    public var category: Category?
    /// Read from the provider, or typed by hand. nil means `auto`.
    public var readMode: ReadMode?
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
    /// The last token report the provider gave for this key, where it publishes
    /// one. Only ever what the provider said, and only shown while its window is
    /// the day we are in.
    public var tokenUse: TokenUse?

    public var isTripped: Bool { status == "tripped" }
    public var isArmed: Bool { armed && !isTripped }

    /// The category to show and group by: this key's own if it has one, the
    /// provider's otherwise.
    public var effectiveCategory: Category {
        category ?? Providers.category(for: provider)
    }

    /// True when the number comes from the person, not from an endpoint.
    public var isManualRead: Bool { readMode == .manual }

    /// The provider this key belongs to, by the name BurnFuse knows that kind of
    /// provider by. Used where the *account* is what is being talked about —
    /// switching a key off at the provider — rather than your own entry.
    public var kindLabel: String { Providers.label(for: provider) }

    /// True when naming the kind beside the entry adds something: a key called
    /// "Prod GPT" belonging to OpenAI says so; one the person named after its
    /// provider already says it, and repeating it is noise. An entry of the
    /// person's own making is never labelled with a kind at all — "Your own
    /// endpoint" is a fact about the form, not about their provider.
    public var showsKindLabel: Bool {
        guard provider != "custom", Providers.known(provider) != nil else { return false }
        return Providers.words(in: name).joined() != Providers.words(in: kindLabel).joined()
    }

    /// "reads itself" or "you type it" — the one distinction that decides what
    /// the figure on a row means, in the same words everywhere it is shown.
    ///
    /// Asked of the key rather than of its provider, because the answer depends
    /// on both: a provider with a cost endpoint is still typed-only until an
    /// address or a key is there to read it with.
    public var readingSourcePhrase: String {
        SpendSource.canReadLive(self) ? "reads itself" : "you type it"
    }

    /// The line under a key's name wherever it is shown: what it is for, whose
    /// account it belongs to when the name does not already say, and how its
    /// number gets in.
    public var subtitlePhrase: String {
        var parts = [effectiveCategory.title]
        if showsKindLabel { parts.append(kindLabel) }
        parts.append(readingSourcePhrase)
        return parts.joined(separator: " · ")
    }

    /// The same line without the category, for rows that are already filed under
    /// their category's band.
    public var readerPhrase: String {
        var parts: [String] = []
        if showsKindLabel { parts.append(kindLabel) }
        parts.append(readingSourcePhrase)
        return parts.joined(separator: " · ")
    }

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
        category: Category? = nil,
        readMode: ReadMode? = nil,
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
        lastCumulativeAt: Double? = nil,
        tokenUse: TokenUse? = nil
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.category = category
        self.readMode = readMode
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
        self.tokenUse = tokenUse
    }

    enum CodingKeys: String, CodingKey {
        case id, name, provider, category, readMode, hourlyLimit, armed, autoKill, status
        case readings, lastReading, trippedAt, createdAt, source
        case lastCumulative, lastCumulativeAt, tokenUse
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Untitled key"
        provider = try c.decodeIfPresent(String.self, forKey: .provider) ?? "custom"
        category = try c.decodeIfPresent(Category.self, forKey: .category)
        readMode = try c.decodeIfPresent(ReadMode.self, forKey: .readMode)
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
        tokenUse = try c.decodeIfPresent(TokenUse.self, forKey: .tokenUse)
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

    /// Spend added up by what the keys are for, biggest first.
    ///
    /// The whole point of a category is this line: "$0.40/hr on images, $2.10 on
    /// coding" is a sentence about your month that a flat list of twelve keys
    /// cannot produce. Categories with nothing burning are left out rather than
    /// printed as a row of zeros.
    public var burnByCategory: [CategoryBurn] {
        var totals: [Category: (burn: Double, cap: Double, tripped: Bool)] = [:]
        for entry in entries {
            let category = entry.effectiveCategory
            let running = totals[category] ?? (0, 0, false)
            totals[category] = (
                running.burn + entry.lastReading,
                running.cap + entry.hourlyLimit,
                running.tripped || entry.isTripped
            )
        }
        return totals
            .map { CategoryBurn(category: $0.key, burn: $0.value.burn, cap: $0.value.cap, tripped: $0.value.tripped) }
            .sorted { $0.burn == $1.burn ? $0.category.rawValue < $1.category.rawValue : $0.burn > $1.burn }
    }
}

/// One row of the by-category breakdown on Overview.
public struct CategoryBurn: Identifiable, Hashable, Sendable {
    public var category: Category
    public var burn: Double
    public var cap: Double
    public var tripped: Bool

    public var id: String { category.rawValue }

    public init(category: Category, burn: Double, cap: Double, tripped: Bool = false) {
        self.category = category
        self.burn = burn
        self.cap = cap
        self.tripped = tripped
    }
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

    /// "2 minutes ago", in the reader's own words, for the timestamps providers
    /// hand back — when a key was last used, when one was made.
    public static func ago(_ date: Date, now: Date = Date()) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: now)
    }

    /// "1.2M", "184.2K", "812" — token counts at the size a person can compare
    /// at a glance, using the system's own compact style so it reads the way
    /// every other number on their Mac does.
    public static func tokens(_ count: Int) -> String {
        count.formatted(.number.notation(.compactName))
    }

    /// The one derived figure in the app's token card: what today's spend on the
    /// keys that report tokens works out to per million of them. It says so in
    /// words, because it is an average over whatever mix of models ran — not a
    /// price list.
    public static func perMillionTokens(spend: Double, tokens: Int) -> String {
        guard tokens > 0 else { return "—" }
        return "\(money(spend / Double(tokens) * 1_000_000)) per million tokens"
    }
}
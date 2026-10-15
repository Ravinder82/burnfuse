import Foundation

/// Where BurnFuse can read live spend directly from a provider.
///
/// Read-only by design: a `GET` that returns a dollar figure, nothing more.
/// Providers without a public spend endpoint are not listed here — those keys
/// are fed by a manual reading instead, which the UI makes a first-class action.
public enum SpendSource {

    /// The outcome of a live read. Never throws: the UI shows the message.
    public struct LiveResult: Sendable {
        public var ok: Bool
        /// The dollar figure the provider returned. For a provider that counts
        /// money up rather than reporting a rate — see `measuresTotal` — this is
        /// that running total, and turning it into `$/hr` is the model's job.
        public var cost: Double?
        public var message: String
        /// The HTTP status, when the provider answered. A dead endpoint should
        /// never read as a rejected key, so the fetcher distinguishes them.
        public var status: Int?

        public init(ok: Bool, cost: Double? = nil, message: String, status: Int? = nil) {
            self.ok = ok
            self.cost = cost
            self.message = message
            self.status = status
        }
    }

    /// The URL to read spend from, or nil when the provider has no endpoint.
    public static func endpoint(for key: BurnKey) -> URL? {
        // An explicit source on the key always wins.
        if let raw = key.source?.spendUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty, let url = URL(string: raw) {
            return url
        }
        switch key.provider {
        case "openai":
            // The costs API only buckets by day. A 1-day bucket is the money
            // spent since UTC midnight, which climbs monotonically — so two
            // reads a little apart give a clean hourly rate. Asking for an
            // hourly bucket is rejected outright.
            let since = Int(Date().timeIntervalSince1970) - 3600
            return URL(string: "https://api.openai.com/v1/organization/costs?start_time=\(since)&bucket_width=1d&limit=1")
        case "anthropic":
            // The cost report is daily-only too, and wants an RFC 3339 window.
            // Ask for the day we are in, so the single bucket it returns is
            // today's running total.
            let dayStart = Date(timeIntervalSince1970: (Date().timeIntervalSince1970 / 86_400).rounded(.down) * 86_400)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            let startingAt = formatter.string(from: dayStart)
            return URL(string: "https://api.anthropic.com/v1/organizations/cost_report?starting_at=\(startingAt)&bucket_width=1d&limit=1")
        case "openrouter":
            // The documented endpoint. An older path (/auth/key) still answers
            // on some accounts and is kept as a fallback.
            return URL(string: "https://openrouter.ai/api/v1/key")
        default:
            return nil
        }
    }

    /// Where else to try if the primary endpoint has moved. Providers relocate
    /// these paths without telling anyone, and a 404 there is a dead address,
    /// not a dead key.
    public static func fallbackEndpoints(for key: BurnKey) -> [URL] {
        guard key.source?.spendUrl?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true else {
            return []
        }
        switch key.provider {
        case "openrouter":
            // The path OpenRouter used before it settled on /api/v1/key. Old
            // keys and older deployments may still answer here.
            if let url = URL(string: "https://openrouter.ai/api/v1/auth/key") { return [url] }
            return []
        default:
            return []
        }
    }

    /// Whether a key can be read live, or needs a manual reading.
    public static func canReadLive(_ key: BurnKey) -> Bool {
        endpoint(for: key) != nil
    }

    /// Whether this provider counts money up rather than reporting an hourly
    /// figure. Both are dollar numbers to the model; only one of them needs
    /// two reads before it means anything.
    ///
    /// All three live providers report a running total: OpenAI by day,
    /// Anthropic by day, OpenRouter for the life of the account.
    public static func measuresTotal(_ key: BurnKey) -> Bool {
        if let measures = key.source?.measures?.trimmingCharacters(in: .whitespaces) {
            return measures == "total"
        }
        switch key.provider {
        case "openai", "anthropic", "openrouter":
            return true
        default:
            return false
        }
    }

    static func headers(for key: BurnKey, apiKey: String?) -> [String: String] {
        var headers: [String: String] = [:]

        // Anthropic authenticates with a header of its own, and asks for a
        // version alongside it.
        if key.provider == "anthropic" {
            headers["anthropic-version"] = "2023-06-01"
        }

        guard let apiKey, !apiKey.isEmpty else { return headers }

        // A custom source can name its own header, which is how endpoints that
        // want `x-api-key` or `api-key` instead of a bearer token get wired up.
        if let custom = key.source?.header?.trimmingCharacters(in: .whitespaces), !custom.isEmpty {
            headers[custom] = custom.caseInsensitiveCompare("Authorization") == .orderedSame
                ? "Bearer \(apiKey)"
                : apiKey
            return headers
        }

        switch key.provider {
        case "anthropic":
            headers["x-api-key"] = apiKey
        default:
            headers["Authorization"] = "Bearer \(apiKey)"
        }
        return headers
    }

    /// Pull a dollar figure out of a decoded JSON body.
    static func parse(provider: String, json: Any, jsonPath: String?) -> Double? {
        if let jsonPath, let value = readPath(json, path: jsonPath) {
            return number(value)
        }
        switch provider {
        case "openai":
            // A day bucket whose results each carry `amount.value`, already USD.
            return sumDayResults(json) { number(($0["amount"] as? [String: Any])?["value"]) }
        case "anthropic":
            // The same day-bucket envelope, but the amount is a decimal string
            // in cents — "123.45" is $1.23 — so a day total is a hundredth.
            return sumDayResults(json) { number($0["amount"]) }.map { $0 / 100 }
        case "openrouter":
            guard let object = json as? [String: Any],
                  let data = object["data"] as? [String: Any] else { return nil }
            // `usage` is all-time credits used, which only ever climbs — the
            // most robust number to take a difference from. Older responses
            // only carried the daily figure.
            return number(data["usage"]) ?? number(data["usage_daily"])
        default:
            return nil
        }
    }

    /// Add up one field across every result in every day bucket of a report.
    /// OpenAI's and Anthropic's cost APIs share this envelope; only the field
    /// holding the amount differs.
    private static func sumDayResults(_ json: Any, _ extract: ([String: Any]) -> Double?) -> Double? {
        guard let object = json as? [String: Any],
              let buckets = object["data"] as? [[String: Any]] else { return nil }
        return buckets.reduce(0.0) { sum, bucket in
            let results = bucket["results"] as? [[String: Any]] ?? []
            return sum + results.reduce(0.0) { inner, result in
                inner + (extract(result) ?? 0)
            }
        }
    }

    static func number(_ value: Any?) -> Double? {
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        if let string = value as? String { return Double(string) }
        if let number = value as? NSNumber { return number.doubleValue }
        return nil
    }

    /// Walk a dotted path like `data.0.results.0.amount.value` through arrays
    /// and objects — the common shapes, without pulling in a JSONPath library.
    static func readPath(_ json: Any, path: String) -> Any? {
        guard !path.isEmpty else { return nil }
        return path.split(separator: ".").reduce(Optional(json)) { current, part in
            switch current {
            case let array as [Any]:
                guard let index = Int(part), index >= 0, index < array.count else { return nil }
                return array[index]
            case let object as [String: Any]:
                return object[String(part)]
            default:
                return nil
            }
        }
    }
}

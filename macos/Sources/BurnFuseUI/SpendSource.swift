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
        case "openrouter":
            return URL(string: "https://openrouter.ai/api/v1/auth/key")
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
            if let url = URL(string: "https://openrouter.ai/api/v1/key") { return [url] }
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
    public static func measuresTotal(_ key: BurnKey) -> Bool {
        if let measures = key.source?.measures?.trimmingCharacters(in: .whitespaces) {
            return measures == "total"
        }
        switch key.provider {
        case "openai", "openrouter":
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
            guard let object = json as? [String: Any],
                  let buckets = object["data"] as? [[String: Any]] else { return nil }
            let total = buckets.reduce(0.0) { sum, bucket in
                let results = bucket["results"] as? [[String: Any]] ?? []
                return sum + results.reduce(0.0) { inner, result in
                    let amount = result["amount"] as? [String: Any]
                    return inner + (number(amount?["value"]) ?? 0)
                }
            }
            return total
        case "openrouter":
            guard let object = json as? [String: Any],
                  let data = object["data"] as? [String: Any] else { return nil }
            return number(data["usage"])
        default:
            return nil
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

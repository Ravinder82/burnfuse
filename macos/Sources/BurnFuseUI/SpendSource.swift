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
        public var cost: Double?
        public var message: String

        public init(ok: Bool, cost: Double? = nil, message: String) {
            self.ok = ok
            self.cost = cost
            self.message = message
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
            let since = Int(Date().timeIntervalSince1970) - 3600
            return URL(string: "https://api.openai.com/v1/organization/costs?start_time=\(since)&bucket_width=1h&limit=1")
        case "openrouter":
            return URL(string: "https://openrouter.ai/api/v1/auth/key")
        default:
            return nil
        }
    }

    /// Whether a key can be read live, or needs a manual reading.
    public static func canReadLive(_ key: BurnKey) -> Bool {
        endpoint(for: key) != nil
    }

    static func headers(for provider: String, apiKey: String?) -> [String: String] {
        guard let apiKey, !apiKey.isEmpty else { return [:] }
        return ["Authorization": "Bearer \(apiKey)"]
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
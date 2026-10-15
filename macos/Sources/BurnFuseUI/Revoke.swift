import Foundation

/// Switching a key off at the provider — the only thing that actually stops the
/// money.
///
/// BurnFuse reads spend. Reading and revoking are different permissions, and an
/// app that blurs them is selling protection it cannot deliver. So this file
/// states, provider by provider, exactly what is possible with the credential
/// BurnFuse already holds — and offers nothing else:
///
///   - **OpenAI** and **Anthropic** publish a cost report for the whole
///     organisation, which only an *Admin* key may read. That same Admin key can
///     also list the account's keys and switch one off. So BurnFuse can do it:
///     you pick the key, the app asks the provider, and the provider's own answer
///     is what you see.
///   - **OpenRouter** changes keys only for a *management* key. The key BurnFuse
///     reads with is an ordinary one, so the switching happens in OpenRouter's
///     console and the app says so instead of pretending.
///   - **Everyone else** documents no such endpoint, so the console is the only
///     door and `Providers.whereToRevoke` names the page.
///
/// Two rules hold throughout: the app never offers a switch-off its credential
/// cannot perform, and it never claims a key is stopped until the provider has
/// said so.
public enum Revoke {

    // MARK: - What the app can do, and how it knows

    /// Whether the credential BurnFuse holds for a provider can switch a key
    /// off. Not a preference: a fact about the provider's API and the kind of
    /// key its spend read requires.
    public enum Ability: Equatable, Sendable {
        /// BurnFuse holds a credential that can list this account's keys and
        /// switch one off. The interface may offer it.
        case canSwitchOff
        /// No API path from the key BurnFuse holds. The console page is the
        /// only place, and `explainer` says why in one sentence.
        case consoleOnly

        public var canSwitchOff: Bool { self == .canSwitchOff }
    }

    public static func ability(for providerID: String) -> Ability {
        switch providerID {
        case "openai", "anthropic": return .canSwitchOff
        default: return .consoleOnly
        }
    }

    /// Why it is possible, or why not, in the words the interface uses.
    public static func explainer(for providerID: String) -> String {
        switch providerID {
        case "openai":
            return "The Admin key BurnFuse reads costs with can also switch keys off — so you can do it here: pick the key, and OpenAI confirms."
        case "anthropic":
            return "The Admin key BurnFuse reads costs with can also set a key to inactive — so you can do it here: pick the key, and Anthropic confirms."
        case "openrouter":
            return "Changing OpenRouter keys needs a management key, and BurnFuse reads with a normal one. So this one happens in OpenRouter's own console, not here."
        default:
            return "\(Providers.label(for: providerID)) has no endpoint for switching a key off. Its console is the only place."
        }
    }

    /// What this provider calls switching a key off — its own verb, so the
    /// button says what will happen.
    public static func switchOffVerb(for providerID: String) -> String {
        switch providerID {
        case "anthropic": return "Set inactive"
        default: return "Delete"
        }
    }

    /// What the provider said happened, in one sentence.
    static func switchedOffMessage(for providerID: String, key: AccountKey) -> String {
        switch providerID {
        case "anthropic":
            return "Anthropic set \(key.hint) to inactive. It can no longer be used or billed."
        case "openai":
            return "OpenAI deleted \(key.hint). It can no longer be used or billed."
        default:
            return "\(Providers.label(for: providerID)) switched \(key.hint) off."
        }
    }

    // MARK: - The account's keys

    /// One key on the provider's account, as the provider describes it.
    ///
    /// The provider's own redaction — OpenAI's `sk-admin…G3H6`, Anthropic's
    /// `sk-ant-api03-R2D…igAA` — is what is shown: enough to recognise the key
    /// you are looking at, never enough to use it. BurnFuse never sees, asks
    /// for, or stores a key it did not already hold.
    public struct AccountKey: Identifiable, Equatable, Sendable {
        public var id: String
        public var name: String
        public var hint: String
        public var lastUsed: Date?
        public var createdAt: Date?
        /// "active" / "inactive" / "archived" where the provider reports it.
        public var status: String?

        public init(id: String, name: String, hint: String,
                    lastUsed: Date? = nil, createdAt: Date? = nil, status: String? = nil) {
            self.id = id
            self.name = name
            self.hint = hint
            self.lastUsed = lastUsed
            self.createdAt = createdAt
            self.status = status
        }

        /// Is this key already switched off? Shown, not offered again.
        public var isInactive: Bool {
            guard let status else { return false }
            return status != "active"
        }
    }

    /// The list request for a provider, or nil when there is none.
    ///
    /// `pageSize` is dropped on a retry because OpenAI documents a default but
    /// no maximum: if 100 is too big for it, asking for the default beats
    /// showing the person an error they can do nothing about.
    static func listURL(for providerID: String, pageSize: Int? = 100) -> URL? {
        switch providerID {
        case "openai":
            let query = pageSize.map { "?limit=\($0)&order=desc" } ?? ""
            return URL(string: "https://api.openai.com/v1/organization/admin_api_keys\(query)")
        case "anthropic":
            // Anthropic documents a range of 1–1000, so this is one page in
            // practice and no paging is needed.
            let query = pageSize.map { "?limit=\($0)" } ?? ""
            return URL(string: "https://api.anthropic.com/v1/organizations/api_keys\(query)")
        default:
            return nil
        }
    }

    /// The request that switches one key off.
    static func switchOffRequest(providerID: String, keyID: String, apiKey: String) -> URLRequest? {
        switch providerID {
        case "openai":
            guard let url = URL(string: "https://api.openai.com/v1/organization/admin_api_keys/\(keyID)") else { return nil }
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            return request
        case "anthropic":
            guard let url = URL(string: "https://api.anthropic.com/v1/organizations/api_keys/\(keyID)") else { return nil }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = Data(#"{"status":"inactive"}"#.utf8)
            return request
        default:
            return nil
        }
    }

    /// Read one page of the account's keys out of the provider's JSON.
    static func parseList(providerID: String, json: Any) -> [AccountKey] {
        guard let object = json as? [String: Any],
              let data = object["data"] as? [[String: Any]] else { return [] }

        return data.compactMap { entry in
            guard let id = entry["id"] as? String else { return nil }
            let name = (entry["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let hint: String
            switch providerID {
            case "openai":
                hint = entry["redacted_value"] as? String ?? ""
            case "anthropic":
                hint = entry["partial_key_hint"] as? String ?? ""
            default:
                hint = ""
            }
            return AccountKey(
                id: id,
                name: (name?.isEmpty == false ? name! : hint.isEmpty ? id : hint),
                hint: hint.isEmpty ? id : hint,
                lastUsed: date(from: entry["last_used_at"]),
                createdAt: date(from: entry["created_at"]),
                status: entry["status"] as? String
            )
        }
    }

    /// Unix seconds or an RFC 3339 string, whichever the provider sends.
    static func date(from value: Any?) -> Date? {
        if let seconds = value as? Double, seconds > 0 { return Date(timeIntervalSince1970: seconds) }
        if let seconds = value as? Int, seconds > 0 { return Date(timeIntervalSince1970: Double(seconds)) }
        if let text = value as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: text) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: text)
        }
        return nil
    }

    /// Does this account key look like the credential BurnFuse is holding?
    ///
    /// Providers redact both ends of a key but keep the tail — "…G3H6" — and the
    /// app holds the full value in its own store, so the tails can be compared
    /// without either side learning anything new. This is how the interface can
    /// warn before someone switches off the very key the readings come from.
    /// A tail shorter than four characters is not treated as a match: too short
    /// to mean anything.
    public static func isTheKeyBurnFuseUses(_ accountKey: AccountKey, localKey: String?) -> Bool {
        guard let localKey, localKey.count >= 4 else { return false }
        guard let separatorRange = accountKey.hint.range(of: "…") ?? accountKey.hint.range(of: "...") else {
            return false
        }
        let tail = String(accountKey.hint[separatorRange.upperBound...])
            .filter { $0.isLetter || $0.isNumber }
        guard tail.count >= 4 else { return false }
        return localKey.lowercased().hasSuffix(tail.lowercased())
    }

    // MARK: - Results

    public struct ListResult: Sendable {
        public var ok: Bool
        public var keys: [AccountKey]
        public var message: String
    }

    public struct Outcome: Sendable {
        public var ok: Bool
        public var message: String
    }

    // MARK: - Doing it

    /// Ask the provider for the account's keys. Never throws: the panel shows
    /// whatever came back, including a refusal.
    public static func list(providerID: String, apiKey: String?,
                            session: URLSession = .shared) async -> ListResult {
        let label = Providers.label(for: providerID)
        guard let apiKey, !apiKey.isEmpty else {
            return ListResult(ok: false, keys: [],
                              message: "BurnFuse has no \(label) key to ask with. Paste one in Settings first.")
        }
        guard let url = listURL(for: providerID) else {
            return ListResult(ok: false, keys: [],
                              message: explainer(for: providerID))
        }

        func fetch(_ url: URL) async throws -> (Int?, Data) {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            applyAuth(&request, providerID: providerID, apiKey: apiKey)
            let (data, response) = try await session.data(for: request)
            return ((response as? HTTPURLResponse)?.statusCode, data)
        }

        do {
            var (status, data) = try await fetch(url)
            // A page size this provider will not take is not the person's
            // problem: ask again the way the provider documents its default.
            if status == 400, let fallback = listURL(for: providerID, pageSize: nil) {
                (status, data) = try await fetch(fallback)
            }
            if status == 200, let json = try? JSONSerialization.jsonObject(with: data) {
                let keys = parseList(providerID: providerID, json: json)
                return ListResult(ok: true, keys: keys, message: keys.isEmpty
                    ? "\(label) listed no keys on this account."
                    : "")
            }
            return ListResult(ok: false, keys: [], message: refusal(providerID: providerID, status: status))
        } catch {
            return ListResult(ok: false, keys: [],
                              message: "Could not reach \(label): \(error.localizedDescription)")
        }
    }

    /// Switch one key off at the provider, and report what the provider said.
    public static func switchOff(providerID: String, key: AccountKey, apiKey: String?,
                                 session: URLSession = .shared) async -> Outcome {
        let label = Providers.label(for: providerID)
        guard let apiKey, !apiKey.isEmpty else {
            return Outcome(ok: false, message: "BurnFuse has no \(label) key to do this with.")
        }
        guard let request = switchOffRequest(providerID: providerID, keyID: key.id, apiKey: apiKey) else {
            return Outcome(ok: false, message: explainer(for: providerID))
        }

        do {
            let (_, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode
            if status == 200 || status == 204 {
                return Outcome(ok: true, message: switchedOffMessage(for: providerID, key: key))
            }
            return Outcome(ok: false, message: refusal(providerID: providerID, status: status))
        } catch {
            return Outcome(ok: false,
                           message: "Could not reach \(label): \(error.localizedDescription). Nothing was switched off.")
        }
    }

    private static func applyAuth(_ request: inout URLRequest, providerID: String, apiKey: String) {
        switch providerID {
        case "anthropic":
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        default:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
    }

    /// A refusal, said as what it is. A refused *action* must never read as a
    /// successful one, and a stale credential must say so.
    static func refusal(providerID: String, status: Int?) -> String {
        let label = Providers.label(for: providerID)
        switch status {
        case 401:
            return "\(label) turned the request down: the key BurnFuse reads with is not valid any more. Paste a fresh Admin key and try again."
        case 403:
            return "\(label) refused: the key BurnFuse holds is not allowed to manage keys. Changing keys needs an Admin key."
        case 404:
            return "\(label) does not know that key any more — it may already be switched off. Reload the list."
        case 429:
            return "\(label) is rate-limiting the request. Try again in a minute."
        case let code? where code >= 500:
            return "\(label) reported a server error (\(code)). Nothing was changed."
        case let code?:
            return "\(label) refused the request (\(code)). Nothing was changed."
        default:
            return "\(label) did not answer. Nothing was changed."
        }
    }
}

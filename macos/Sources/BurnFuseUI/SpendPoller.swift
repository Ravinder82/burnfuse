import Foundation

/// Performs the actual live read. Small, isolated, and easy to point at a
/// temporary URL in tests.
public enum SpendPoller {

    /// Why nothing could even be tried, in plain words.
    ///
    /// A 401 from a provider is a sentence about a key: "this key is not valid".
    /// When the value that would have been sent is a stand-in out of a sample
    /// file, that sentence is false — no key was sent at all — so the reason is
    /// named here instead of asking the provider to mis-describe it.
    public static func missingKeyMessage(
        for key: BurnKey,
        source: Credentials.KeySource
    ) -> String {
        let label = Providers.label(for: key.provider)
        switch source {
        case .storedPlaceholder:
            return "The \(label) key saved here is the placeholder from a sample file, not a real key. Paste the key itself from the \(label) console."
        case .environmentPlaceholder(let variable):
            return "\(variable) in your environment is the placeholder from a sample file, not a real key, so BurnFuse ignores it. Paste a real \(label) key in Settings."
        case .stored, .environment, .none:
            return "No \(label) key saved yet. Paste one in Settings to read spend live."
        }
    }

    /// Read live spend for a key. Returns a structured result rather than
    /// throwing, so callers can always show a plain-language message.
    public static func fetch(
        _ key: BurnKey,
        apiKey: String?,
        timeout: TimeInterval = 8,
        session: URLSession = .shared
    ) async -> SpendSource.LiveResult {
        // Nothing was ever given to read with. Asking anyway gets a 401, which
        // reads exactly like a rejected key — the single most confusing thing
        // this app could say to someone who simply has not pasted a key yet.
        if SpendSource.requiresKey(key),
           apiKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            return SpendSource.LiveResult(
                ok: false,
                message: missingKeyMessage(for: key, source: .none)
            )
        }

        let candidates = [SpendSource.endpoint(for: key)].compactMap { $0 }
            + SpendSource.fallbackEndpoints(for: key)

        guard !candidates.isEmpty else {
            return SpendSource.LiveResult(
                ok: false,
                message: "\(Providers.label(for: key.provider)) has no live spend endpoint. Log a reading instead."
            )
        }

        var failure = SpendSource.LiveResult(ok: false, message: "", status: nil)
        for candidate in candidates {
            let attempt = await read(key, url: candidate, apiKey: apiKey, timeout: timeout, session: session)
            if attempt.ok { return attempt }

            failure = attempt
            // Only a missing address is worth trying elsewhere. Anything else
            // is about the key or the account, and a retry will not change it.
            if attempt.status != 404, attempt.status != 410 { break }
        }

        // The first endpoint moved and nothing answered, so report the address
        // rather than blaming the key the user just pasted.
        if candidates.count > 1, (failure.status == 404 || failure.status == 410) {
            return SpendSource.LiveResult(
                ok: false,
                message: "BurnFuse could not find \(Providers.label(for: key.provider))'s cost endpoint.",
                status: failure.status
            )
        }
        return failure
    }

    /// One address, one request.
    private static func read(
        _ key: BurnKey,
        url: URL,
        apiKey: String?,
        timeout: TimeInterval,
        session: URLSession
    ) async -> SpendSource.LiveResult {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (field, value) in SpendSource.headers(for: key, apiKey: apiKey) {
            request.setValue(value, forHTTPHeaderField: field)
        }

        do {
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode
            if let status, !(200..<300).contains(status) {
                return SpendSource.LiveResult(
                    ok: false,
                    message: message(for: status, key: key),
                    status: status
                )
            }

            let json = try? JSONSerialization.jsonObject(with: data)
            guard let json else {
                return SpendSource.LiveResult(
                    ok: false,
                    message: "The provider's response was not readable.",
                    status: status
                )
            }

            guard let cost = SpendSource.parse(provider: key.provider, json: json, jsonPath: key.source?.jsonPath) else {
                return SpendSource.LiveResult(
                    ok: false,
                    message: "Could not find a dollar amount in the response.",
                    status: status
                )
            }

            return SpendSource.LiveResult(
                ok: true,
                cost: cost,
                message: SpendSource.measuresTotal(key)
                    ? "Read a running total of \(Fmt.money(cost))."
                    : "Read \(Fmt.perHour(cost)).",
                status: status
            )
        } catch let error as URLError {
            return SpendSource.LiveResult(ok: false, message: message(for: error, key: key), status: nil)
        } catch {
            return SpendSource.LiveResult(ok: false, message: "The read failed: \(error.localizedDescription)")
        }
    }

    /// Say what actually happened, in words a person can act on. The single
    /// most common failure with this app is a perfectly good key of the wrong
    /// kind, and "HTTP 401" tells them nothing about that.
    private static func message(for status: Int, key: BurnKey) -> String {
        let label = Providers.label(for: key.provider)
        switch status {
        case 400:
            return "\(label) did not accept that request (400)."
        case 401, 403:
            return rejected(status, key: key)
        case 404:
            return "\(label) could not find that endpoint (404)."
        case 429:
            return "\(label) is rate-limiting reads (429). It will retry in a minute."
        case 500..<600:
            return "\(label) is having trouble (\(status)). It will retry in a minute."
        default:
            return "\(label) returned HTTP \(status)."
        }
    }

    /// A key the provider turned down. The most common failure in this app is a
    /// perfectly good key of the wrong kind, so each provider says which kind it
    /// wanted rather than leaving the user to guess at a status code.
    private static func rejected(_ status: Int, key: BurnKey) -> String {
        let invalid = status == 401
        switch key.provider {
        case "openai":
            return invalid
                ? "OpenAI said this key is not valid (401). The costs API only answers an Admin key — one that starts with sk-admin-."
                : "OpenAI refused this key (403). An Admin key without access to organization costs reads nothing."
        case "anthropic":
            return invalid
                ? "Anthropic said this key is not valid (401). Reading spend needs an Admin key on an organization account — individual accounts have no Admin API."
                : "Anthropic refused this key (403). An Admin key on an individual account cannot read spend."
        case "openrouter":
            return invalid
                ? "OpenRouter said this key is not valid (401). Check it in Settings — OpenRouter keys start with sk-or-."
                : "OpenRouter refused this key (403). Check it in Settings."
        default:
            return invalid
                ? "The provider said this key is not valid (\(status)). Check it in Settings."
                : "The provider refused this key (\(status)). It may not have access to billing."
        }
    }

    /// Plain words for the network failures people actually hit, instead of the
    /// raw error string.
    private static func message(for error: URLError, key: BurnKey) -> String {
        let label = Providers.label(for: key.provider)
        switch error.code {
        case .timedOut:
            return "\(label) did not answer in time."
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            return "There is no internet connection right now."
        case .cannotConnectToHost, .dnsLookupFailed:
            return "Could not reach \(label)."
        case .secureConnectionFailed:
            return "A secure connection to \(label) could not be made."
        case .cancelled:
            return "The read was cancelled."
        default:
            return "The read failed: \(error.localizedDescription)"
        }
    }

    /// POST a plain-text alert to a Slack/Discord/generic webhook. Fire-and-forget.
    public static func notify(
        webhook: String,
        text: String,
        timeout: TimeInterval = 6,
        session: URLSession = .shared
    ) async {
        guard !webhook.isEmpty, let url = URL(string: webhook) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = webhook.contains("discord.com") ? ["content": text] : ["text": text]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        _ = try? await session.data(for: request)
    }
}

import Foundation

/// Performs the actual live read. Small, isolated, and easy to point at a
/// temporary URL in tests.
public enum SpendPoller {

    /// Read live spend for a key. Returns a structured result rather than
    /// throwing, so callers can always show a plain-language message.
    public static func fetch(
        _ key: BurnKey,
        apiKey: String?,
        timeout: TimeInterval = 8,
        session: URLSession = .shared
    ) async -> SpendSource.LiveResult {
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
        case 401:
            return "\(label) said this key is not valid (401). Check it in Settings."
        case 403:
            return "\(label) refused this key (403). It may not have access to billing."
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

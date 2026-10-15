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
        guard let url = SpendSource.endpoint(for: key) else {
            return SpendSource.LiveResult(
                ok: false,
                message: "\(Providers.label(for: key.provider)) has no live spend endpoint. Log a reading instead."
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (field, value) in SpendSource.headers(for: key.provider, apiKey: apiKey) {
            request.setValue(value, forHTTPHeaderField: field)
        }

        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                let hint = http.statusCode == 401 || http.statusCode == 403
                    ? " Check the key in Settings."
                    : ""
                return SpendSource.LiveResult(ok: false, message: "The provider returned HTTP \(http.statusCode).\(hint)")
            }

            let json = try? JSONSerialization.jsonObject(with: data)
            guard let json else {
                return SpendSource.LiveResult(ok: false, message: "The provider's response was not readable.")
            }

            guard let cost = SpendSource.parse(provider: key.provider, json: json, jsonPath: key.source?.jsonPath) else {
                return SpendSource.LiveResult(ok: false, message: "Could not find a dollar amount in the response.")
            }

            return SpendSource.LiveResult(ok: true, cost: cost, message: "Read \(Fmt.perHour(cost)).")
        } catch let error as URLError where error.code == .timedOut {
            return SpendSource.LiveResult(ok: false, message: "The provider did not answer in time.")
        } catch {
            return SpendSource.LiveResult(ok: false, message: error.localizedDescription)
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
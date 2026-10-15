import XCTest
import Foundation
@testable import BurnFuseUI

/// The app's own data layer: pulling a dollar figure out of a provider
/// response, and keeping provider keys local.
final class SpendSourceTests: XCTestCase {

    // MARK: - Parsing provider shapes

    func testParsesOpenAICostBuckets() throws {
        let json = """
        {"data":[{"results":[{"amount":{"value":1.25,"currency":"usd"}},
                              {"amount":{"value":0.10,"currency":"usd"}}]}]}
        """
        let body = try JSONSerialization.jsonObject(with: Data(json.utf8))
        let cost = SpendSource.parse(provider: "openai", json: body, jsonPath: nil)
        XCTAssertEqual(try XCTUnwrap(cost), 1.35, accuracy: 0.0001)
    }

    func testParsesOpenRouterUsage() throws {
        let json = #"{"data":{"usage":3.42,"label":"key"}}"#
        let body = try JSONSerialization.jsonObject(with: Data(json.utf8))
        let cost = SpendSource.parse(provider: "openrouter", json: body, jsonPath: nil)
        XCTAssertEqual(try XCTUnwrap(cost), 3.42, accuracy: 0.0001)
    }

    func testExplicitJSONPathWins() throws {
        let json = #"{"totals":{"hourly":7.5},"usage":1}"#
        let body = try JSONSerialization.jsonObject(with: Data(json.utf8))
        let cost = SpendSource.parse(provider: "custom", json: body, jsonPath: "totals.hourly")
        XCTAssertEqual(try XCTUnwrap(cost), 7.5, accuracy: 0.0001)
    }

    func testReadPathWalksArraysAndObjects() throws {
        let json = #"{"data":[{"results":[{"amount":{"value":0.42}}]}]}"#
        let body = try JSONSerialization.jsonObject(with: Data(json.utf8))
        let value = SpendSource.readPath(body, path: "data.0.results.0.amount.value")
        XCTAssertEqual(SpendSource.number(value), 0.42)
    }

    func testMissingValueReturnsNil() throws {
        let body = try JSONSerialization.jsonObject(with: Data(#"{"unrelated":true}"#.utf8))
        XCTAssertNil(SpendSource.parse(provider: "openai", json: body, jsonPath: nil))
        XCTAssertNil(SpendSource.parse(provider: "custom", json: body, jsonPath: "nope.deep"))
    }

    // MARK: - Endpoints

    func testLiveSupportByProvider() {
        let openAI = BurnKey(id: "a", name: "a", provider: "openai")
        let openRouter = BurnKey(id: "b", name: "b", provider: "openrouter")
        let anthropic = BurnKey(id: "c", name: "c", provider: "anthropic")
        let groq = BurnKey(id: "d", name: "d", provider: "groq")

        XCTAssertTrue(SpendSource.canReadLive(openAI))
        XCTAssertTrue(SpendSource.canReadLive(openRouter))
        XCTAssertTrue(SpendSource.canReadLive(anthropic))
        XCTAssertFalse(SpendSource.canReadLive(groq), "no public endpoint — log a reading instead")

        XCTAssertEqual(SpendSource.endpoint(for: openRouter)?.absoluteString,
                       "https://openrouter.ai/api/v1/key")
        XCTAssertNotNil(SpendSource.endpoint(for: openAI)?.absoluteString.range(of: "organization/costs"))
    }

    // MARK: - Endpoints

    func testOpenAIReadsADayBucketNotAnHour() {
        let url = try? XCTUnwrap(SpendSource.endpoint(for: BurnKey(id: "a", name: "a", provider: "openai")))
        let query = url?.query ?? ""
        XCTAssertTrue(query.contains("bucket_width=1d"), "the costs API only buckets by day")
        XCTAssertFalse(query.contains("1h"), "an hourly bucket is rejected outright")
    }

    func testAProviderWithAMovedEndpointHasAFallback() {
        let openRouter = BurnKey(id: "b", name: "b", provider: "openrouter")
        XCTAssertEqual(SpendSource.endpoint(for: openRouter)?.absoluteString,
                       "https://openrouter.ai/api/v1/key")
        XCTAssertEqual(SpendSource.fallbackEndpoints(for: openRouter).first?.absoluteString,
                       "https://openrouter.ai/api/v1/auth/key")

        // A custom endpoint has no second address to try.
        var custom = BurnKey(id: "d", name: "d", provider: "custom")
        custom.source = KeySource(spendUrl: "https://example.com/cost.json")
        XCTAssertTrue(SpendSource.fallbackEndpoints(for: custom).isEmpty)
    }

    func testCustomKeyUsesItsOwnSourceURL() {
        var key = BurnKey(id: "d", name: "d", provider: "custom")
        XCTAssertFalse(SpendSource.canReadLive(key), "custom with no URL has nothing to read")
        key.source = KeySource(spendUrl: "https://example.com/cost.json", jsonPath: "total")
        XCTAssertTrue(SpendSource.canReadLive(key))
        XCTAssertEqual(SpendSource.endpoint(for: key)?.absoluteString, "https://example.com/cost.json")
    }

    // MARK: - Rate versus running total

    /// Providers that count money up cannot be read as a rate on the first
    /// pass — that is the whole reason the model holds a baseline.
    func testCumulativeProvidersNeedTwoReads() {
        XCTAssertTrue(SpendSource.measuresTotal(BurnKey(id: "a", name: "a", provider: "openai")))
        XCTAssertTrue(SpendSource.measuresTotal(BurnKey(id: "b", name: "b", provider: "openrouter")))
        XCTAssertTrue(SpendSource.measuresTotal(BurnKey(id: "c", name: "c", provider: "anthropic")))
        XCTAssertFalse(SpendSource.measuresTotal(BurnKey(id: "d", name: "d", provider: "groq")),
                       "Groq has no public spend endpoint — log a reading instead")
    }

    func testACustomSourceSaysWhichKindOfNumberItReports() {
        var rate = BurnKey(id: "d", name: "d", provider: "custom")
        rate.source = KeySource(spendUrl: "https://example.com/cost.json", measures: "rate")
        XCTAssertFalse(SpendSource.measuresTotal(rate))

        var total = BurnKey(id: "e", name: "e", provider: "custom")
        total.source = KeySource(spendUrl: "https://example.com/cost.json", measures: "total")
        XCTAssertTrue(SpendSource.measuresTotal(total))
    }

    // MARK: - Headers

    func testAuthorizationHeaderOnlyWhenKeyPresent() {
        XCTAssertTrue(SpendSource.headers(for: BurnKey(id: "a", name: "a", provider: "openai"), apiKey: nil).isEmpty)
        let bearer = SpendSource.headers(for: BurnKey(id: "a", name: "a", provider: "openai"), apiKey: "sk-test")
        XCTAssertEqual(bearer["Authorization"], "Bearer sk-test")
    }

    func testAnthropicUsesAHeaderOfItsOwn() {
        let headers = SpendSource.headers(for: BurnKey(id: "c", name: "c", provider: "anthropic"), apiKey: "sk-ant-admin-1")
        XCTAssertEqual(headers["x-api-key"], "sk-ant-admin-1")
        XCTAssertNil(headers["Authorization"])
        XCTAssertEqual(headers["anthropic-version"], "2023-06-01")
    }

    func testACustomSourceCanNameItsOwnHeader() {
        var key = BurnKey(id: "d", name: "d", provider: "custom")
        key.source = KeySource(spendUrl: "https://example.com/cost.json", header: "x-api-key")

        let headers = SpendSource.headers(for: key, apiKey: "secret")
        // Anything other than Authorization carries the key on its own, without
        // a Bearer prefix the endpoint would reject.
        XCTAssertEqual(headers["x-api-key"], "secret")
        XCTAssertNil(headers["Authorization"])
    }

    // MARK: - Live fetch

    func testFetchReadsAValueFromTheProvider() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.responder = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test")
            let body = #"{"data":{"usage":4.25,"label":"key"}}"#
            return (200, Data(body.utf8))
        }
        let session = StubURLProtocol.session()
        let key = BurnKey(id: "b", name: "b", provider: "openrouter")

        let result = await SpendPoller.fetch(key, apiKey: "sk-test", session: session)
        XCTAssertTrue(result.ok, result.message)
        XCTAssertEqual(try XCTUnwrap(result.cost), 4.25, accuracy: 0.0001)
    }

    func testFetchReportsAnHTTPErrorPlainly() async {
        StubURLProtocol.reset()
        StubURLProtocol.responder = { _ in (401, Data()) }
        let key = BurnKey(id: "b", name: "b", provider: "openrouter")

        let result = await SpendPoller.fetch(key, apiKey: "bad", session: StubURLProtocol.session())
        XCTAssertFalse(result.ok)
        XCTAssertTrue(result.message.contains("401"), result.message)
        XCTAssertEqual(result.status, 401)
    }

    /// A provider moving its endpoint is not the same as a bad key, and must
    /// not be reported as one.
    func testA404FallsThroughToTheFallbackEndpoint() async {
        StubURLProtocol.reset()
        // The documented path has moved; the older one still answers.
        StubURLProtocol.responder = { request in
            guard request.url?.absoluteString.contains("/api/v1/auth/key") == true else {
                return (404, Data())
            }
            return (200, Data(#"{"data":{"usage":4.25,"label":"key"}}"#.utf8))
        }
        let key = BurnKey(id: "b", name: "b", provider: "openrouter")

        let result = await SpendPoller.fetch(key, apiKey: "sk-or-1", session: StubURLProtocol.session())
        XCTAssertTrue(result.ok, result.message)
        XCTAssertEqual(try XCTUnwrap(result.cost), 4.25, accuracy: 0.0001)
    }

    func testWhenEveryEndpointIsGoneTheAddressIsBlamedNotTheKey() async {
        StubURLProtocol.reset()
        StubURLProtocol.responder = { _ in (404, Data()) }
        let key = BurnKey(id: "b", name: "b", provider: "openrouter")

        let result = await SpendPoller.fetch(key, apiKey: "sk-or-1", session: StubURLProtocol.session())
        XCTAssertFalse(result.ok)
        XCTAssertTrue(result.message.contains("endpoint"), result.message)
    }

    func testAFailedConnectionReportsIt() async {
        StubURLProtocol.reset()
        let key = BurnKey(id: "b", name: "b", provider: "openrouter")

        let result = await SpendPoller.fetch(key, apiKey: "sk-or-1", session: StubURLProtocol.session())
        XCTAssertFalse(result.ok)
        XCTAssertFalse(result.message.isEmpty, "a network failure still says something")
    }

    func testFetchExplainsWhenAProviderHasNoEndpoint() async {
        let key = BurnKey(id: "c", name: "c", provider: "groq")
        let result = await SpendPoller.fetch(key, apiKey: nil, session: StubURLProtocol.session())
        XCTAssertFalse(result.ok)
        XCTAssertTrue(result.message.contains("Log a reading"), result.message)
    }

    // MARK: - Anthropic

    func testAnthropicReadsADayBucketForToday() {
        let url = SpendSource.endpoint(for: BurnKey(id: "c", name: "c", provider: "anthropic"))
        let text = url?.absoluteString ?? ""
        XCTAssertTrue(text.contains("/v1/organizations/cost_report"), text)
        XCTAssertTrue(text.contains("bucket_width=1d"), "the cost report is daily only, like OpenAI's")
        XCTAssertTrue(text.contains("starting_at="), "the report needs an explicit window")
    }

    /// Anthropic reports costs as decimal strings in cents, so a day total has
    /// to be divided by a hundred or every figure is a hundred times too big.
    func testAnthropicAmountsAreCents() {
        let body: [String: Any] = [
            "data": [
                [
                    "starting_at": "2025-08-01T00:00:00Z",
                    "ending_at": "2025-08-02T00:00:00Z",
                    "results": [
                        ["amount": "123.45", "currency": "USD", "cost_type": "tokens"],
                        ["amount": "76.55", "currency": "USD", "cost_type": "web_search"],
                    ],
                ]
            ],
            "has_more": false,
        ]
        // 123.45 + 76.55 cents = 200 cents = $2.00.
        XCTAssertEqual(try XCTUnwrap(SpendSource.parse(provider: "anthropic", json: body, jsonPath: nil)),
                       2.0, accuracy: 0.0001)
    }

    func testAnthropicWithNoCostsReadsZeroRatherThanFailing() {
        let body: [String: Any] = [
            "data": [["starting_at": "2025-08-01T00:00:00Z", "ending_at": "2025-08-02T00:00:00Z", "results": [Any]()]],
            "has_more": false,
        ]
        XCTAssertEqual(try XCTUnwrap(SpendSource.parse(provider: "anthropic", json: body, jsonPath: nil)),
                       0, accuracy: 0.0001)
    }

    func testAnthropicCountsUpLikeOpenAI() {
        XCTAssertTrue(SpendSource.measuresTotal(BurnKey(id: "c", name: "c", provider: "anthropic")))
    }

    /// The single most likely failure for an Anthropic key: a personal account
    /// has no Admin API at all, so the message has to say that rather than
    /// leaving the user to guess what "401" means.
    func testAnAnthropicRejectionNamesTheAdminRequirement() async {
        StubURLProtocol.reset()
        StubURLProtocol.responder = { _ in (401, Data()) }
        let key = BurnKey(id: "c", name: "c", provider: "anthropic")

        let result = await SpendPoller.fetch(key, apiKey: "sk-ant-api03-x", session: StubURLProtocol.session())
        XCTAssertFalse(result.ok)
        XCTAssertTrue(result.message.contains("(401)"), result.message)
        XCTAssertTrue(result.message.contains("Admin key"), result.message)
        XCTAssertTrue(result.message.contains("individual accounts"), result.message)
    }

    func testAnOpenAIRejectionNamesTheAdminKeyPrefix() async {
        StubURLProtocol.reset()
        StubURLProtocol.responder = { _ in (401, Data()) }
        let key = BurnKey(id: "a", name: "a", provider: "openai")

        let result = await SpendPoller.fetch(key, apiKey: "sk-proj-x", session: StubURLProtocol.session())
        XCTAssertFalse(result.ok)
        XCTAssertTrue(result.message.contains("sk-admin-"), result.message)
    }

    func testOpenRouterReadsAllTimeUsageWithADailyFallback() {
        let allTime: [String: Any] = ["data": ["usage": 12.5, "usage_daily": 0.4]]
        XCTAssertEqual(try? XCTUnwrap(SpendSource.parse(provider: "openrouter", json: allTime, jsonPath: nil)),
                       12.5)

        // Older responses only carried the daily counter.
        let dailyOnly: [String: Any] = ["data": ["usage_daily": 0.4]]
        XCTAssertEqual(try? XCTUnwrap(SpendSource.parse(provider: "openrouter", json: dailyOnly, jsonPath: nil)),
                       0.4)
    }

    // MARK: - A key that was never given

    func testOnlyTheLiveProvidersInsistOnAKey() {
        for id in ["openai", "anthropic", "openrouter"] {
            XCTAssertTrue(SpendSource.requiresKey(BurnKey(id: id, name: id, provider: id)), id)
        }
        // A custom endpoint may be a public page of your own, so only the user
        // can know whether it wants a key.
        XCTAssertFalse(SpendSource.requiresKey(BurnKey(id: "d", name: "d", provider: "custom")))
    }

    /// The whole point: someone who has not pasted a key yet must not be told
    /// their key is invalid. Nothing is asked of the provider at all.
    func testAReadWithNoKeySaysSoInsteadOfBlamingTheKey() async {
        // A responder that would fail loudly if it were ever reached.
        StubURLProtocol.reset()
        let key = BurnKey(id: "a", name: "a", provider: "openai")

        let result = await SpendPoller.fetch(key, apiKey: nil, session: StubURLProtocol.session())
        XCTAssertFalse(result.ok)
        XCTAssertNil(result.status, "no request should have been made")
        XCTAssertTrue(result.message.contains("No OpenAI key stored yet"), result.message)
        XCTAssertTrue(result.message.contains("Settings"), result.message)
        XCTAssertFalse(result.message.contains("401"), result.message)

        // A blank string is the same as no key.
        let blank = await SpendPoller.fetch(key, apiKey: "   ", session: StubURLProtocol.session())
        XCTAssertTrue(blank.message.contains("No OpenAI key stored yet"), blank.message)
    }

    /// A custom endpoint is still tried with no key, because it may not want one.
    func testACustomEndpointIsStillTriedWithoutAKey() async {
        StubURLProtocol.reset()
        defer { StubURLProtocol.reset() }
        StubURLProtocol.responder = { _ in (200, Data(#"{"total":1.5}"#.utf8)) }

        var key = BurnKey(id: "d", name: "d", provider: "custom")
        key.source = KeySource(spendUrl: "https://example.com/cost.json", jsonPath: "total", measures: "rate")

        let result = await SpendPoller.fetch(key, apiKey: nil, session: StubURLProtocol.session())
        XCTAssertTrue(result.ok, result.message)
        XCTAssertEqual(try? XCTUnwrap(result.cost), 1.5)
    }
}

/// A tiny URLProtocol that answers every request from a closure, so the live
/// path can be exercised without touching the network.
final class StubURLProtocol: URLProtocol {
    static var responder: ((URLRequest) -> (Int, Data))?
    static let lock = NSLock()

    static func reset() { responder = nil }

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        StubURLProtocol.lock.lock()
        let responder = StubURLProtocol.responder
        StubURLProtocol.lock.unlock()

        guard let responder else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (status, data) = responder(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// Provider keys must stay on the machine, owner-readable, and never leak into
/// the state file.
final class CredentialsTests: XCTestCase {

    private func tempKeysURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("burnfuse-keys-\(UUID().uuidString).json")
    }

    func testStoreReadAndClearRoundTrip() {
        let url = tempKeysURL()
        setenv("BURNFUSE_KEYS", url.path, 1)
        unsetenv("OPENROUTER_API_KEY")
        defer {
            unsetenv("BURNFUSE_KEYS")
            try? FileManager.default.removeItem(at: url)
        }

        XCTAssertNil(Credentials.key(for: "openrouter"))
        Credentials.set("sk-or-secret", for: "openrouter")
        XCTAssertEqual(Credentials.key(for: "openrouter"), "sk-or-secret")

        Credentials.set("   ", for: "openrouter")
        XCTAssertNil(Credentials.key(for: "openrouter"), "whitespace clears the key")
    }

    func testEnvironmentValueWinsOverStoredFile() {
        let url = tempKeysURL()
        setenv("BURNFUSE_KEYS", url.path, 1)
        setenv("OPENROUTER_API_KEY", "from-environment", 1)
        defer {
            unsetenv("BURNFUSE_KEYS")
            unsetenv("OPENROUTER_API_KEY")
            try? FileManager.default.removeItem(at: url)
        }

        Credentials.set("from-file", for: "openrouter")
        XCTAssertEqual(Credentials.key(for: "openrouter"), "from-environment")
    }

    func testStoredFileIsOwnerReadableOnly() throws {
        let url = tempKeysURL()
        setenv("BURNFUSE_KEYS", url.path, 1)
        defer {
            unsetenv("BURNFUSE_KEYS")
            try? FileManager.default.removeItem(at: url)
        }

        Credentials.set("sk-or-secret", for: "openrouter")
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let permissions = try XCTUnwrap(attributes[.posixPermissions] as? NSNumber)
        XCTAssertEqual(permissions.intValue, 0o600, "keys are readable only by the owner")
    }

    func testEnvironmentVariableIsKnownPerProvider() {
        XCTAssertEqual(Credentials.environmentVariable(for: "openai"), "OPENAI_ADMIN_KEY")
        XCTAssertEqual(Credentials.environmentVariable(for: "openrouter"), "OPENROUTER_API_KEY")
        XCTAssertNil(Credentials.environmentVariable(for: "custom"))
    }

    // MARK: - What people actually paste

    func testSanitizingRemovesTheJunkThatRidesAlongWithAKey() {
        XCTAssertEqual(Credentials.sanitize("  sk-or-1\n"), "sk-or-1")
        // A paste from a doc or a header dump already carries its scheme.
        XCTAssertEqual(Credentials.sanitize("Bearer sk-or-1"), "sk-or-1")
        // A paste from a JSON file or a chat message is quoted.
        XCTAssertEqual(Credentials.sanitize("\"sk-or-1\""), "sk-or-1")
        XCTAssertEqual(Credentials.sanitize("“sk-or-1”"), "sk-or-1")
        XCTAssertEqual(Credentials.sanitize("'sk-or-1'"), "sk-or-1")
        XCTAssertEqual(Credentials.sanitize("’sk-or-1’"), "sk-or-1")
        // Two things pasted at once is always a mistake.
        XCTAssertEqual(Credentials.sanitize("sk-or-1\nsk-or-2"), "sk-or-1sk-or-2")
    }

    func testSanitizingNothingLeavesNothing() {
        XCTAssertNil(Credentials.sanitize(""))
        XCTAssertNil(Credentials.sanitize("   \n  "))
        XCTAssertNil(Credentials.sanitize("\"\""))
    }

    func testSanitizingKeepsAWorkingKeyIntact() {
        // A real OpenRouter key contains dots and dashes and nothing else.
        XCTAssertEqual(Credentials.sanitize("sk-or-v1-0123456789abcdef"), "sk-or-v1-0123456789abcdef")
        // And it must not eat a key that merely contains an equals sign, the
        // way a base64 padding character would.
        XCTAssertEqual(Credentials.sanitize("abc123=="), "abc123==")
    }

    func testAPastedKeyIsCleanedBeforeItIsStored() {
        let url = tempKeysURL()
        setenv("BURNFUSE_KEYS", url.path, 1)
        unsetenv("OPENROUTER_API_KEY")
        defer {
            unsetenv("BURNFUSE_KEYS")
            try? FileManager.default.removeItem(at: url)
        }

        Credentials.set("\"Bearer sk-or-pasted\"", for: "openrouter")
        XCTAssertEqual(Credentials.key(for: "openrouter"), "sk-or-pasted")
    }

    // MARK: - Masking

    func testAMaskedKeyShowsOnlyItsEnds() {
        XCTAssertEqual(Credentials.mask("sk-or-v1-0123456789abcdef"), "sk-o…cdef")
    }

    func testAMaskedShortValueRevealsLessNotMore() {
        // There is nothing to recognise in a short value, so a mask must not
        // suddenly show all of it.
        XCTAssertEqual(Credentials.mask("short"), "sh…")
        XCTAssertEqual(Credentials.mask("12345678"), "12…")
        XCTAssertEqual(Credentials.mask("123456789"), "1234…6789")
    }

    func testMaskedIsNilWithoutAKeyAndTheEndsWithOne() {
        let url = tempKeysURL()
        setenv("BURNFUSE_KEYS", url.path, 1)
        unsetenv("OPENROUTER_API_KEY")
        defer {
            unsetenv("BURNFUSE_KEYS")
            try? FileManager.default.removeItem(at: url)
        }

        XCTAssertNil(Credentials.masked(for: "openrouter"))
        Credentials.set("sk-or-v1-0123456789abcdef", for: "openrouter")
        XCTAssertEqual(Credentials.masked(for: "openrouter"), "sk-o…cdef")
    }

    func testTheAppSaysWhenAKeyComesFromTheEnvironment() {
        let url = tempKeysURL()
        setenv("BURNFUSE_KEYS", url.path, 1)
        defer {
            unsetenv("BURNFUSE_KEYS")
            unsetenv("OPENROUTER_API_KEY")
            try? FileManager.default.removeItem(at: url)
        }

        XCTAssertFalse(Credentials.isFromEnvironment(for: "openrouter"))
        Credentials.set("from-file", for: "openrouter")
        XCTAssertFalse(Credentials.isFromEnvironment(for: "openrouter"), "the file is not the environment")

        setenv("OPENROUTER_API_KEY", "from-environment", 1)
        XCTAssertTrue(Credentials.isFromEnvironment(for: "openrouter"))
        // And the environment still wins for the value itself.
        XCTAssertEqual(Credentials.key(for: "openrouter"), "from-environment")
    }
}
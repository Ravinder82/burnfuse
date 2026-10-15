import XCTest
import Foundation
@testable import BurnFuseUI

/// The token card is the one place in the app that explains a dollar figure
/// rather than reporting it, so the tests here are mostly about the boundary
/// between "the provider counts tokens" and "the provider does not":
///
///   - what a provider's own response actually contains, field by field
///   - that a day with no usage reads as zero rather than as missing, and a
///     response with no envelope reads as missing rather than as zero
///   - that a reading from yesterday is never shown under today's heading
///   - that a failed token read cannot damage a spend read that worked
final class TokenUseTests: XCTestCase {

    // MARK: - The daily window

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func utcDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func testDayStartIsMidnightUTC() {
        let afternoon = utcDate(2026, 10, 15, 17, 38)
        let midnight = utcDate(2026, 10, 15)
        let yesterday = utcDate(2026, 10, 14)

        XCTAssertEqual(TokenUse.dayStart(for: afternoon), midnight.timeIntervalSince1970 * 1000, accuracy: 1)
        XCTAssertEqual(TokenUse.dayStart(for: midnight), TokenUse.dayStart(for: afternoon), accuracy: 1)
        XCTAssertEqual(TokenUse.dayStart(for: midnight.addingTimeInterval(-1)),
                       yesterday.timeIntervalSince1970 * 1000,
                       accuracy: 1, "one second before midnight is yesterday")
    }

    func testAYesterdaysReadingIsNotToday() {
        let now = utcDate(2026, 10, 15, 17, 38)
        let today = TokenUse(input: 1, output: 1, windowStart: TokenUse.dayStart(for: now))
        let yesterday = TokenUse(input: 1, output: 1,
                                 windowStart: TokenUse.dayStart(for: now.addingTimeInterval(-86_400)))
        XCTAssertTrue(today.isCurrent(now: now))
        XCTAssertFalse(yesterday.isCurrent(now: now))
    }

    func testTotalIsInputPlusOutputAndNeverDoubleCountsTheCache() {
        let use = TokenUse(input: 100, output: 40, cachedInput: 80, windowStart: 0)
        XCTAssertEqual(use.total, 140)
    }

    // MARK: - What the providers send

    func testOpenAICountsAddUpAcrossResultsAndBuckets() throws {
        let json: [String: Any] = [
            "object": "page",
            "data": [
                [
                    "object": "bucket",
                    "start_time": 1_761_148_800,
                    "end_time": 1_761_235_200,
                    "results": [
                        [
                            "input_tokens": 1_000,
                            "input_cached_tokens": 800,
                            "output_tokens": 250,
                            "num_model_requests": 12,
                        ],
                        [
                            "input_tokens": 500,
                            "input_cached_tokens": 0,
                            "output_tokens": 100,
                            "num_model_requests": 3,
                        ],
                    ],
                ],
            ],
        ]

        let use = try XCTUnwrap(SpendSource.parseTokens(provider: "openai", json: json))
        XCTAssertEqual(use.input, 1_500, "input counts everything, cached included")
        XCTAssertEqual(use.output, 350)
        XCTAssertEqual(use.cachedInput, 800, "cached is a part of input, not extra")
        XCTAssertEqual(use.requests, 15)
        XCTAssertEqual(use.windowStart, 1_761_148_800_000)
    }

    func testAnthropicCountsItsThreeKindsOfInput() throws {
        let json: [String: Any] = [
            "data": [
                [
                    "starting_at": "2026-10-15T00:00:00Z",
                    "ending_at": "2026-10-16T00:00:00Z",
                    "results": [
                        [
                            "uncached_input_tokens": 1_000,
                            "cache_read_input_tokens": 3_000,
                            "cache_creation": [
                                "ephemeral_1h_input_tokens": 200,
                                "ephemeral_5m_input_tokens": 400,
                            ],
                            "output_tokens": 700,
                        ],
                    ],
                ],
            ],
        ]

        let use = try XCTUnwrap(SpendSource.parseTokens(provider: "anthropic", json: json))
        XCTAssertEqual(use.input, 4_600, "all three kinds of input, none of them overlapping")
        XCTAssertEqual(use.output, 700)
        XCTAssertEqual(use.cachedInput, 3_000)
        XCTAssertNil(use.requests, "Anthropic does not count requests, so the app does not claim one")
    }

    func testADayWithNoUsageIsAnAnswerOfZero() throws {
        let openai: [String: Any] = ["data": [[
            "start_time": 1_761_148_800,
            "results": [],
        ]]]
        let use = try XCTUnwrap(SpendSource.parseTokens(provider: "openai", json: openai))
        XCTAssertEqual(use.input, 0)
        XCTAssertEqual(use.output, 0)
        XCTAssertNil(use.cachedInput, "no results means no cache figure was reported")
    }

    func testAResponseWithNoEnvelopeIsNotReadAsZero() {
        XCTAssertNil(SpendSource.parseTokens(provider: "openai", json: ["error": "nope"]))
        XCTAssertNil(SpendSource.parseTokens(provider: "openai", json: "not json"))
        XCTAssertNil(SpendSource.parseTokens(provider: "openai", json: [String: Any]()))
    }

    func testOpenRouterIsNeverAskedForTokens() {
        XCTAssertFalse(SpendSource.reportsTokens("openrouter"))
        XCTAssertFalse(SpendSource.reportsTokens("fal"))
        XCTAssertTrue(SpendSource.reportsTokens("openai"))
        XCTAssertTrue(SpendSource.reportsTokens("anthropic"))
    }

    // MARK: - The requests

    private func key(provider: String, readMode: ReadMode? = nil, source: KeySource? = nil) -> BurnKey {
        BurnKey(id: "k1", name: "test", provider: provider, readMode: readMode, source: source)
    }

    func testTheTokenReadCoversTheDayWeAreIn() throws {
        let url = try XCTUnwrap(SpendSource.tokenEndpoint(for: key(provider: "openai")))
        XCTAssertEqual(url.host, "api.openai.com")
        XCTAssertEqual(url.path, "/v1/organization/usage/completions")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let start = try XCTUnwrap(items.first { $0.name == "start_time" }?.value)
        XCTAssertEqual(try XCTUnwrap(Double(start)), TokenUse.dayStart(for: Date()) / 1000, accuracy: 1,
                       "the window has to be the day the money is measured over")
        XCTAssertEqual(items.first { $0.name == "bucket_width" }?.value, "1d")
    }

    func testAnthropicsTokenReadAsksForTheSameDay() throws {
        let url = try XCTUnwrap(SpendSource.tokenEndpoint(for: key(provider: "anthropic")))
        XCTAssertEqual(url.path, "/v1/organizations/usage_report/messages")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let startingAt = try XCTUnwrap(items.first { $0.name == "starting_at" }?.value)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let parsed = try XCTUnwrap(formatter.date(from: startingAt))
        XCTAssertEqual(parsed.timeIntervalSince1970, TokenUse.dayStart(for: Date()) / 1000, accuracy: 1)
    }

    func testAKeyWhoseNumbersComeFromYouIsNeverAskedForTokens() {
        XCTAssertNil(SpendSource.tokenEndpoint(for: key(provider: "openai", readMode: .manual)))
    }

    func testAKeyWiredToYourOwnEndpointIsNeverAskedForTokens() {
        let custom = KeySource(spendUrl: "https://example.com/cost.json", jsonPath: "total")
        XCTAssertNil(SpendSource.tokenEndpoint(for: key(provider: "openai", source: custom)))
    }

    // MARK: - The read itself

    private func isolate() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("burnfuse-keys-\(UUID().uuidString).json")
        setenv("BURNFUSE_KEYS", url.path, 1)
        for name in ["OPENAI_ADMIN_KEY", "OPENROUTER_API_KEY", "ANTHROPIC_ADMIN_KEY"] {
            unsetenv(name)
        }
        return url
    }

    private func restore(_ url: URL) {
        unsetenv("BURNFUSE_KEYS")
        unsetenv("OPENAI_ADMIN_KEY")
        unsetenv("OPENROUTER_API_KEY")
        unsetenv("ANTHROPIC_ADMIN_KEY")
        try? FileManager.default.removeItem(at: url)
    }

    func testAFailedTokenReadReturnsNothingRatherThanAFigure() async throws {
        let keysURL = try isolate()
        defer { restore(keysURL) }

        StubURLProtocol.reset()
        defer { StubURLProtocol.reset() }

        StubURLProtocol.responder = { _ in (500, Data("{}".utf8)) }
        let use = await SpendPoller.fetchTokens(key(provider: "openai"), apiKey: "sk-admin-test",
                                                session: StubURLProtocol.session())
        XCTAssertNil(use, "a token report that could not be read is nothing, not zero")
    }

    func testATokenReadThatWorksComesBackWithTheCounts() async throws {
        let keysURL = try isolate()
        defer { restore(keysURL) }

        StubURLProtocol.reset()
        defer { StubURLProtocol.reset() }

        StubURLProtocol.responder = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
            let body = #"{"data":[{"starting_at":"2026-10-15T00:00:00Z","results":[{"uncached_input_tokens":9,"cache_read_input_tokens":1,"output_tokens":5}]}]}"#
            return (200, Data(body.utf8))
        }
        let use = await SpendPoller.fetchTokens(key(provider: "anthropic"), apiKey: "sk-ant-admin-test",
                                                session: StubURLProtocol.session())
        let counts = try XCTUnwrap(use)
        XCTAssertEqual(counts.input, 10)
        XCTAssertEqual(counts.output, 5)
    }

    // MARK: - The wiring: one read, two requests, one failure allowed

    @MainActor
    private func model() -> AppModel {
        AppModel(
            stateURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("burnfuse-tokens-\(UUID().uuidString).json"),
            pollInterval: 0
        )
    }

    /// A token report that fails must leave the money reading alone: the dollar
    /// figure was read, and it is the figure the breaker acts on.
    @MainActor
    func testASpendReadSurvivesATokenReadThatFails() async throws {
        let keysURL = try isolate()
        defer { restore(keysURL) }
        Credentials.set("sk-admin-test", for: "openai")

        StubURLProtocol.reset()
        defer { StubURLProtocol.reset() }
        StubURLProtocol.responder = { request in
            if request.url?.path.contains("usage") == true { return (500, Data("{}".utf8)) }
            let body = #"{"object":"page","data":[{"start_time":1761148800,"results":[{"amount":{"value":3.5,"currency":"usd"}}]}]}"#
            return (200, Data(body.utf8))
        }

        let model = model()
        _ = model.addKey(name: "OpenAI prod", provider: "openai", cap: 5, category: .coding)
        await model.refreshLive(session: StubURLProtocol.session())

        let entry = try XCTUnwrap(model.state.entries.first)
        XCTAssertEqual(entry.lastCumulative ?? -1, 3.5, accuracy: 0.0001,
                       "the money was read and has to stay read")
        XCTAssertNil(entry.tokenUse, "and nothing may be invented for the tokens")
        XCTAssertFalse(model.lastReadFailed(entry.id), "a token failure is not a spend failure")
    }

    @MainActor
    func testTheTokensLandOnTheKeyWhenTheProviderCountsThem() async throws {
        let keysURL = try isolate()
        defer { restore(keysURL) }
        Credentials.set("sk-admin-test", for: "openai")

        StubURLProtocol.reset()
        defer { StubURLProtocol.reset() }
        StubURLProtocol.responder = { request in
            if request.url?.path.contains("usage") == true {
                let day = Int(TokenUse.dayStart(for: Date()) / 1000)
                let body = "{\"data\":[{\"start_time\":\(day),\"results\":[{\"input_tokens\":1000,\"input_cached_tokens\":800,\"output_tokens\":250,\"num_model_requests\":7}]}]}"
                return (200, Data(body.utf8))
            }
            let day = Int(TokenUse.dayStart(for: Date()) / 1000)
            let body = "{\"object\":\"page\",\"data\":[{\"start_time\":\(day),\"results\":[{\"amount\":{\"value\":3.5,\"currency\":\"usd\"}}]}]}"
            return (200, Data(body.utf8))
        }

        let model = model()
        _ = model.addKey(name: "OpenAI prod", provider: "openai", cap: 5, category: .coding)
        await model.refreshLive(session: StubURLProtocol.session())

        let use = try XCTUnwrap(model.state.entries.first?.tokenUse)
        XCTAssertEqual(use.input, 1_000)
        XCTAssertEqual(use.output, 250)
        XCTAssertEqual(use.cachedInput, 800)
        XCTAssertTrue(use.isCurrent(), "the reading has to be for the day we are in")
    }

    @MainActor
    func testAnOpenRouterKeyIsNotAskedForTokens() async throws {
        let keysURL = try isolate()
        defer { restore(keysURL) }
        Credentials.set("sk-or-test", for: "openrouter")

        StubURLProtocol.reset()
        defer { StubURLProtocol.reset() }
        StubURLProtocol.responder = { _ in
            (200, Data(#"{"data":{"usage":1.0,"limit":6.5,"limit_remaining":5.0}}"#.utf8))
        }

        let model = model()
        _ = model.addKey(name: "OpenRouter", provider: "openrouter", cap: 5, category: .coding)
        await model.refreshLive(session: StubURLProtocol.session())

        XCTAssertEqual(StubURLProtocol.requestedCount, 1, "one request: the spend read, and nothing else")
        XCTAssertNil(model.state.entries.first?.tokenUse)
    }

    // MARK: - How it is said

    func testPerMillionTokensIsOnlyComputedFromRealNumbers() {
        XCTAssertEqual(Fmt.perMillionTokens(spend: 3, tokens: 1_000_000), "$3.00 per million tokens")
        XCTAssertEqual(Fmt.perMillionTokens(spend: 3, tokens: 0), "—")
    }

    func testTokenCountsAreShownCompactly() {
        // The form is the reader's own: the number goes through the system's
        // compact style, so a machine set to a locale that counts in lakhs sees
        // lakhs, and one that counts in millions sees millions. What must hold
        // everywhere is that a big count is short and is not spelled out.
        XCTAssertEqual(Fmt.tokens(0), "0")
        XCTAssertLessThan(Fmt.tokens(4_700_000).count, "4700000".count,
                          "a seven-figure token count has to read at a glance")
        XCTAssertFalse(Fmt.tokens(4_700_000).contains("4700000"))
        XCTAssertFalse(Fmt.tokens(12_400).contains("12400"))
        XCTAssertTrue(Fmt.tokens(812).contains("812"), "three figures need no abbreviation anywhere")
    }
}

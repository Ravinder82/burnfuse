import XCTest
import Foundation
@testable import BurnFuseUI

/// The provider's own ceiling on a key — the one number that answers "can this
/// key still spend?" without anyone's help.
///
/// BurnFuse reports it and never claims to have set it: a person watching a
/// spend needs to know whether the floor under them is real.
final class CreditLimitTests: XCTestCase {

    private func openRouter(limit: Any?, remaining: Any? = nil, usage: Any? = nil) -> [String: Any] {
        var data: [String: Any] = ["label": "sk-or-v1-…1578", "usage": usage ?? 0]
        if let limit { data["limit"] = limit }
        if let remaining { data["limit_remaining"] = remaining }
        return ["data": data]
    }

    func testASpentCapSaysRequestsAreRefused() throws {
        let limit = try XCTUnwrap(SpendSource.parseLimit(
            provider: "openrouter",
            json: openRouter(limit: 6.5, remaining: 0)
        ))
        XCTAssertEqual(limit.limit, 6.5, accuracy: 0.0001)
        XCTAssertEqual(limit.remaining, 0, accuracy: 0.0001)
        XCTAssertTrue(limit.isSpent)
        XCTAssertTrue(limit.sentence.contains("refused"), limit.sentence)
        XCTAssertTrue(limit.sentence.contains("$6.50"), limit.sentence)
    }

    func testARemainingCapSaysWhereARunawayStops() throws {
        let limit = try XCTUnwrap(SpendSource.parseLimit(
            provider: "openrouter",
            json: openRouter(limit: 10, remaining: 4.5)
        ))
        XCTAssertFalse(limit.isSpent)
        XCTAssertTrue(limit.sentence.contains("$4.50 is left"), limit.sentence)
        XCTAssertTrue(limit.sentence.contains("runaway stops here"), limit.sentence)
    }

    func testASettableButUnsetLimitIsNotACapOfZero() {
        // OpenRouter answers `limit: null` for a key with no ceiling. Reading
        // that as "$0 left" would be the app inventing a protection that is not
        // there.
        XCTAssertNil(SpendSource.parseLimit(provider: "openrouter", json: openRouter(limit: nil)))
    }

    func testARemainingFigureIsDerivedOnlyWhenTheProviderOmitsIt() throws {
        let limit = try XCTUnwrap(SpendSource.parseLimit(
            provider: "openrouter",
            json: openRouter(limit: 10, usage: 8)
        ))
        XCTAssertEqual(limit.remaining, 2, accuracy: 0.0001)
    }

    func testProvidersThatPublishNoCeilingSayNothing() {
        let openai: [String: Any] = ["data": [["results": [["amount": ["value": 1.0]]]]]]
        XCTAssertNil(SpendSource.parseLimit(provider: "openai", json: openai))
        let anthropic: [String: Any] = ["data": [["results": [["amount": "123.45"]]]]]
        XCTAssertNil(SpendSource.parseLimit(provider: "anthropic", json: anthropic))
    }

    func testGarbageIsNotReadAsACap() {
        XCTAssertNil(SpendSource.parseLimit(provider: "openrouter", json: "not json"))
        XCTAssertNil(SpendSource.parseLimit(provider: "openrouter", json: [String: Any]()))
    }

    func testTheSentenceNeverClaimsBurnFuseSetTheCap() throws {
        let limit = try XCTUnwrap(SpendSource.parseLimit(
            provider: "openrouter",
            json: openRouter(limit: 6.5, remaining: 1)
        ))
        XCTAssertTrue(limit.sentence.contains("The provider caps this key"),
                      "the cap belongs to the provider, and the words must say so")
    }

    // MARK: - The wiring: the ceiling has to reach the screen's model

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
        unsetenv("OPENROUTER_API_KEY")
        try? FileManager.default.removeItem(at: url)
    }

    @MainActor
    func testASpentCeilingIsKeptSoTheRowCanSaySo() async throws {
        let keysURL = try isolate()
        defer { restore(keysURL) }
        Credentials.set("sk-or-test", for: "openrouter")

        StubURLProtocol.reset()
        defer { StubURLProtocol.reset() }
        StubURLProtocol.responder = { _ in
            (200, Data(#"{"data":{"label":"sk-or-v1-…1578","usage":6.5631,"limit":6.5,"limit_remaining":0}}"#.utf8))
        }

        let model = AppModel(
            stateURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("burnfuse-limit-\(UUID().uuidString).json"),
            pollInterval: 0
        )
        let key = model.addKey(name: "OpenRouter", provider: "openrouter", cap: 5, category: .coding)
        await model.refreshLive(session: StubURLProtocol.session())

        let limit = try XCTUnwrap(model.keyLimits[key.id],
                                  "a ceiling the provider reported has to reach the row")
        XCTAssertEqual(limit.limit, 6.5, accuracy: 0.0001)
        XCTAssertTrue(limit.isSpent)
    }

    @MainActor
    func testAKeyWithNoCeilingLeavesNothingToSay() async throws {
        let keysURL = try isolate()
        defer { restore(keysURL) }
        Credentials.set("sk-or-test", for: "openrouter")

        StubURLProtocol.reset()
        defer { StubURLProtocol.reset() }
        // OpenRouter answers `limit: null` for a key with no ceiling set.
        StubURLProtocol.responder = { _ in
            (200, Data(#"{"data":{"label":"sk-or-v1-…1578","usage":1.0,"limit":null,"limit_remaining":null}}"#.utf8))
        }

        let model = AppModel(
            stateURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("burnfuse-limit-\(UUID().uuidString).json"),
            pollInterval: 0
        )
        let key = model.addKey(name: "OpenRouter", provider: "openrouter", cap: 5, category: .coding)
        await model.refreshLive(session: StubURLProtocol.session())

        XCTAssertNil(model.keyLimits[key.id],
                     "no ceiling is not a ceiling of zero, and the row must stay quiet")
    }
}

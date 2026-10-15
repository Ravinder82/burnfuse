import XCTest
import Foundation
@testable import BurnFuseUI

/// Switching a key off is the only action in this app that stops money, so the
/// tests here are mostly about *not* doing it: not offering it where the
/// credential cannot perform it, not sending a request with no key, not reading
/// a refusal as a success, and not confusing the key BurnFuse reads with for
/// some other key on the account.
final class RevokeTests: XCTestCase {

    // MARK: - Where it is possible at all

    func testOfferedForTheProvidersWhoseReadKeyCanAlsoManageKeys() {
        XCTAssertTrue(Revoke.ability(for: "openai").canSwitchOff)
        XCTAssertTrue(Revoke.ability(for: "anthropic").canSwitchOff)
    }

    func testNotOfferedWhereTheReadKeyCannotManageKeys() {
        // OpenRouter changes keys only for a management key; the app reads with a
        // normal one. Everything else has no such endpoint at all.
        for id in ["openrouter", "replicate", "groq", "custom", "aws", "fal"] {
            XCTAssertFalse(Revoke.ability(for: id).canSwitchOff, "\(id) should not offer a switch-off")
        }
    }

    func testEveryProviderExplainsItselfHonestly() {
        for provider in Providers.all {
            let explainer = Revoke.explainer(for: provider.id)
            XCTAssertFalse(explainer.isEmpty, "\(provider.id) has no explanation")
            if Revoke.ability(for: provider.id).canSwitchOff {
                XCTAssertTrue(explainer.contains("Admin key"),
                              "\(provider.id) should say which key does it")
            } else {
                XCTAssertTrue(
                    explainer.contains("console") || explainer.contains("management key"),
                    "\(provider.id) should say where the switching really happens: \(explainer)"
                )
            }
        }
    }

    func testOpenRouterSaysManagementKeyNotConsoleOnly() {
        XCTAssertTrue(Revoke.explainer(for: "openrouter").contains("management key"))
    }

    // MARK: - Reading the account's keys

    func testParsesOpenAIsKeyList() {
        let json: [String: Any] = [
            "object": "list",
            "data": [
                [
                    "id": "key_abc",
                    "object": "organization.admin_api_key",
                    "name": "prod server",
                    "redacted_value": "sk-admin…G3H6",
                    "created_at": 1_711_471_533,
                    "last_used_at": 1_711_471_534,
                ],
                [
                    "id": "key_def",
                    "name": "old key",
                    "redacted_value": "sk-admin…0000",
                    "created_at": 1_711_000_000,
                ],
            ],
        ]

        let keys = Revoke.parseList(providerID: "openai", json: json)
        XCTAssertEqual(keys.count, 2)
        XCTAssertEqual(keys[0].id, "key_abc")
        XCTAssertEqual(keys[0].name, "prod server")
        XCTAssertEqual(keys[0].hint, "sk-admin…G3H6")
        XCTAssertEqual(keys[0].lastUsed, Date(timeIntervalSince1970: 1_711_471_534))
        XCTAssertNil(keys[1].lastUsed, "a key never used has no last-used time")
    }

    func testParsesAnthropicsKeyListIncludingStatus() {
        let json: [String: Any] = [
            "data": [
                [
                    "id": "apikey_01",
                    "type": "api_key",
                    "name": "Claude batch",
                    "partial_key_hint": "sk-ant-api03-R2D…igAA",
                    "status": "active",
                    "created_at": "2026-01-02T03:04:05Z",
                ],
                [
                    "id": "apikey_02",
                    "name": "retired",
                    "partial_key_hint": "sk-ant-api03-AAA…BBBB",
                    "status": "inactive",
                    "created_at": "2025-11-30T10:00:00.000Z",
                ],
            ],
        ]

        let keys = Revoke.parseList(providerID: "anthropic", json: json)
        XCTAssertEqual(keys.count, 2)
        XCTAssertEqual(keys[0].name, "Claude batch")
        XCTAssertEqual(keys[0].status, "active")
        XCTAssertFalse(keys[0].isInactive)
        XCTAssertEqual(keys[1].status, "inactive")
        XCTAssertTrue(keys[1].isInactive, "an inactive key must not be offered again")
        XCTAssertNotNil(keys[0].createdAt)
    }

    func testUnnamedKeyFallsBackToItsHintSoTheRowIsNeverBlank() {
        let json: [String: Any] = [
            "data": [["id": "key_xyz", "redacted_value": "sk-admin…ZZZZ"]],
        ]
        let keys = Revoke.parseList(providerID: "openai", json: json)
        XCTAssertEqual(keys.first?.name, "sk-admin…ZZZZ")
    }

    func testGarbageInTheListIsIgnoredRatherThanCrashing() {
        XCTAssertTrue(Revoke.parseList(providerID: "openai", json: "not json").isEmpty)
        XCTAssertTrue(Revoke.parseList(providerID: "openai", json: ["data": [[:] ]] as [String: Any]).isEmpty)
    }

    // MARK: - Telling the app's own key from the others

    func testRecognisesTheKeyBurnFuseItselfReadsWith() {
        let accountKey = Revoke.AccountKey(id: "key_abc", name: "prod",
                                           hint: "sk-admin…G3H6")
        // The stored value is the real-looking demo key from the renderer.
        let local = "sk-admin-01J8ZQ4K7F2M9T3B6N5R8V1X4C7D0G3H6"
        XCTAssertTrue(Revoke.isTheKeyBurnFuseUses(accountKey, localKey: local))
    }

    func testAnthropicHintsMatchToo() {
        let accountKey = Revoke.AccountKey(id: "apikey_01", name: "batch",
                                           hint: "sk-ant-admin01-K9…G0hJ3")
        let local = "sk-ant-admin01-K9mQ2rT5vX8zB3nM6pL1wY4cD7fG0hJ3"
        XCTAssertTrue(Revoke.isTheKeyBurnFuseUses(accountKey, localKey: local))
    }

    func testADifferentKeyIsNotMistakenForOurs() {
        let accountKey = Revoke.AccountKey(id: "key_abc", name: "other",
                                           hint: "sk-admin…AAAA")
        let local = "sk-admin-01J8ZQ4K7F2M9T3B6N5R8V1X4C7D0G3H6"
        XCTAssertFalse(Revoke.isTheKeyBurnFuseUses(accountKey, localKey: local))
    }

    func testTooShortATailIsNeverAMatch() {
        let accountKey = Revoke.AccountKey(id: "key_abc", name: "x", hint: "sk-admin…123")
        let local = "sk-admin-123"
        XCTAssertFalse(Revoke.isTheKeyBurnFuseUses(accountKey, localKey: local),
                       "three characters is not enough to identify a key")
    }

    func testAHintWithNoRedactionNeverMatches() {
        let accountKey = Revoke.AccountKey(id: "key_abc", name: "x", hint: "key_abc")
        let local = "sk-admin-01J8ZQ4K7F2M9T3B6N5R8V1X4C7D0G3H6"
        XCTAssertFalse(Revoke.isTheKeyBurnFuseUses(accountKey, localKey: local))
    }

    // MARK: - The requests themselves

    func testOpenAISwitchOffIsADeleteWithTheAdminKey() throws {
        let request = try XCTUnwrap(Revoke.switchOffRequest(providerID: "openai", keyID: "key_abc",
                                                            apiKey: "sk-admin-test"))
        XCTAssertEqual(request.httpMethod, "DELETE")
        XCTAssertEqual(request.url?.absoluteString,
                       "https://api.openai.com/v1/organization/admin_api_keys/key_abc")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer sk-admin-test")
    }

    func testAnthropicSwitchOffSetsTheKeyInactive() throws {
        let request = try XCTUnwrap(Revoke.switchOffRequest(providerID: "anthropic", keyID: "apikey_01",
                                                            apiKey: "sk-ant-admin-test"))
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString,
                       "https://api.anthropic.com/v1/organizations/api_keys/apikey_01")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "sk-ant-admin-test")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        let body = String(data: try XCTUnwrap(request.httpBody), encoding: .utf8)
        XCTAssertEqual(body, #"{"status":"inactive"}"#)
    }

    func testNoRequestIsMadeForAProviderWithNoEndpoint() {
        XCTAssertNil(Revoke.switchOffRequest(providerID: "openrouter", keyID: "x", apiKey: "k"))
        XCTAssertNil(Revoke.listURL(for: "openrouter"))
    }

    // MARK: - What the provider says back

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
        for name in ["OPENAI_ADMIN_KEY", "OPENROUTER_API_KEY", "ANTHROPIC_ADMIN_KEY"] {
            unsetenv(name)
        }
        try? FileManager.default.removeItem(at: url)
    }

    func testListingWithoutAKeySendsNothingAndSaysSo() async throws {
        let keysURL = try isolate()
        defer { restore(keysURL) }

        StubURLProtocol.reset()
        defer { StubURLProtocol.reset() }

        let result = await Revoke.list(providerID: "openai", apiKey: nil,
                                       session: StubURLProtocol.session())
        XCTAssertFalse(result.ok)
        XCTAssertEqual(StubURLProtocol.requestedCount, 0,
                       "with no key there is nothing to ask with, so nothing may be sent")
        XCTAssertTrue(result.message.contains("no OpenAI key"), result.message)
    }

    func testAListingComesBackWithTheKeys() async throws {
        let keysURL = try isolate()
        defer { restore(keysURL) }

        StubURLProtocol.reset()
        defer { StubURLProtocol.reset() }

        let body = #"{"object":"list","data":[{"id":"key_abc","name":"prod","redacted_value":"sk-admin…G3H6","created_at":1711471533}]}"#
        StubURLProtocol.responder = { _ in (200, Data(body.utf8)) }

        let result = await Revoke.list(providerID: "openai", apiKey: "sk-admin-test",
                                       session: StubURLProtocol.session())
        XCTAssertTrue(result.ok, result.message)
        XCTAssertEqual(result.keys.count, 1)
        XCTAssertEqual(result.keys.first?.hint, "sk-admin…G3H6")
        XCTAssertEqual(StubURLProtocol.lastRequest?.httpMethod, "GET")
    }

    func testAPageSizeTheProviderWillNotTakeFallsBackToItsDefault() async throws {
        let keysURL = try isolate()
        defer { restore(keysURL) }

        StubURLProtocol.reset()
        defer { StubURLProtocol.reset() }

        // OpenAI documents a default page size and no maximum, so a size it will
        // not take must not become an error the person can do nothing about.
        StubURLProtocol.responder = { request in
            if request.url?.query?.contains("limit=") == true { return (400, Data("{}".utf8)) }
            return (200, Data(#"{"data":[{"id":"key_abc","name":"prod","redacted_value":"sk-admin…G3H6"}]}"#.utf8))
        }
        let result = await Revoke.list(providerID: "openai", apiKey: "sk-admin-test",
                                       session: StubURLProtocol.session())
        XCTAssertTrue(result.ok, result.message)
        XCTAssertEqual(result.keys.count, 1)
        XCTAssertEqual(StubURLProtocol.requestedCount, 2, "it should ask twice, then work")
    }

    func testAForbiddenListingSaysItNeedsAnAdminKey() async throws {
        let keysURL = try isolate()
        defer { restore(keysURL) }

        StubURLProtocol.reset()
        defer { StubURLProtocol.reset() }

        StubURLProtocol.responder = { _ in (403, Data("{}".utf8)) }
        let result = await Revoke.list(providerID: "openai", apiKey: "sk-normal",
                                       session: StubURLProtocol.session())
        XCTAssertFalse(result.ok)
        XCTAssertTrue(result.message.contains("Admin key"), result.message)
    }

    func testASuccessfulSwitchOffSaysWhatTheProviderDid() async throws {
        let keysURL = try isolate()
        defer { restore(keysURL) }

        StubURLProtocol.reset()
        defer { StubURLProtocol.reset() }

        StubURLProtocol.responder = { _ in (200, Data(#"{"id":"key_abc","deleted":true}"#.utf8)) }
        let key = Revoke.AccountKey(id: "key_abc", name: "prod", hint: "sk-admin…G3H6")
        let outcome = await Revoke.switchOff(providerID: "openai", key: key, apiKey: "sk-admin-test",
                                             session: StubURLProtocol.session())
        XCTAssertTrue(outcome.ok)
        XCTAssertTrue(outcome.message.contains("no longer be used or billed"), outcome.message)
        XCTAssertEqual(StubURLProtocol.lastRequest?.httpMethod, "DELETE")
    }

    func testARefusedSwitchOffIsNeverReadAsASuccess() async throws {
        let keysURL = try isolate()
        defer { restore(keysURL) }

        StubURLProtocol.reset()
        defer { StubURLProtocol.reset() }

        StubURLProtocol.responder = { _ in (403, Data("{}".utf8)) }
        let key = Revoke.AccountKey(id: "key_abc", name: "prod", hint: "sk-admin…G3H6")
        let outcome = await Revoke.switchOff(providerID: "openai", key: key, apiKey: "sk-normal",
                                             session: StubURLProtocol.session())
        XCTAssertFalse(outcome.ok)
        XCTAssertTrue(outcome.message.contains("refused"), outcome.message)
        XCTAssertFalse(outcome.message.contains("no longer be used or billed"),
                       "a refusal must never read like a success")
    }

    func testAKeyTheProviderNoLongerKnowsSaysSo() async throws {
        let keysURL = try isolate()
        defer { restore(keysURL) }

        StubURLProtocol.reset()
        defer { StubURLProtocol.reset() }

        StubURLProtocol.responder = { _ in (404, Data("{}".utf8)) }
        let key = Revoke.AccountKey(id: "key_gone", name: "prod", hint: "sk-admin…G3H6")
        let outcome = await Revoke.switchOff(providerID: "openai", key: key, apiKey: "sk-admin-test",
                                             session: StubURLProtocol.session())
        XCTAssertFalse(outcome.ok)
        XCTAssertTrue(outcome.message.contains("already be switched off"), outcome.message)
    }
}

import XCTest
import Foundation
@testable import BurnFuseUI

/// The place the app used to lie: it recorded a provider's running total as if
/// it were dollars per hour, so a key with three dollars of lifetime usage
/// appeared to be burning three dollars an hour forever.
@MainActor
final class LiveReadTests: XCTestCase {

    private func tempKeysURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("burnfuse-keys-\(UUID().uuidString).json")
    }

    private func model() -> AppModel {
        AppModel(
            stateURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("burnfuse-live-\(UUID().uuidString).json"),
            pollInterval: 0
        )
    }

    /// Run against a throwaway key file and a quiet environment, so a real
    /// `~/.burnfuse/keys.json` or a provider variable in the shell cannot change
    /// what is being tested.
    private func isolate() throws -> URL {
        let url = tempKeysURL()
        setenv("BURNFUSE_KEYS", url.path, 1)
        for name in ["OPENAI_ADMIN_KEY", "OPENROUTER_API_KEY", "ANTHROPIC_ADMIN_KEY",
                     "REPLICATE_API_TOKEN", "GROQ_API_KEY", "AWS_ACCESS_KEY_ID"] {
            unsetenv(name)
        }
        return url
    }

    private func restore(_ url: URL) {
        unsetenv("BURNFUSE_KEYS")
        for name in ["OPENAI_ADMIN_KEY", "OPENROUTER_API_KEY", "ANTHROPIC_ADMIN_KEY",
                     "REPLICATE_API_TOKEN", "GROQ_API_KEY", "AWS_ACCESS_KEY_ID"] {
            unsetenv(name)
        }
        try? FileManager.default.removeItem(at: url)
    }

    func testAProviderThatCountsUpNeedsTwoReads() async throws {
        let keysURL = try isolate()
        defer { restore(keysURL) }

        StubURLProtocol.reset()
        defer { StubURLProtocol.reset() }

        // A clock we can move forward an hour without waiting one.
        var now = Date()
        let m = model()
        m.clock = { now }

        m.addKey(name: "Fal images", provider: "custom", cap: 5,
                 spendUrl: "https://example.com/total.json", jsonPath: "total", measures: "total")

        var total = 100.0
        StubURLProtocol.responder = { _ in
            (200, Data("{\"total\": \(total)}".utf8))
        }

        // The first read stores the counter and records nothing. Reporting it
        // now would show a lifetime total as an hourly rate.
        await m.refreshLive(session: StubURLProtocol.session())
        XCTAssertEqual(m.state.entries[0].readings.count, 0)
        XCTAssertEqual(m.state.entries[0].lastCumulative ?? 0, 100, accuracy: 0.0001)
        XCTAssertEqual(m.state.entries[0].lastReading, 0, accuracy: 0.0001)
        XCTAssertTrue(m.lastReadMessage?.contains("baseline") ?? false, m.lastReadMessage ?? "")

        // An hour later the same counter has moved three dollars.
        now = now.addingTimeInterval(3600)
        total = 103
        await m.refreshLive(session: StubURLProtocol.session())

        XCTAssertEqual(m.state.entries[0].readings.count, 1)
        XCTAssertEqual(
            m.state.entries[0].lastReading,
            3.0,
            accuracy: 0.0001,
            "three dollars over an hour is three dollars an hour"
        )
        XCTAssertTrue(m.lastReadMessage?.contains("$3.00/hr") ?? false, m.lastReadMessage ?? "")
    }

    /// A provider that already reports a rate is used as it stands.
    func testAProviderThatReportsARateIsUsedAsItStands() async throws {
        let keysURL = try isolate()
        defer { restore(keysURL) }

        StubURLProtocol.reset()
        defer { StubURLProtocol.reset() }

        let m = model()
        m.addKey(name: "Meter", provider: "custom", cap: 5,
                 spendUrl: "https://example.com/rate.json", jsonPath: "perHour", measures: "rate")
        StubURLProtocol.responder = { _ in (200, Data(#"{"perHour": 2.5}"#.utf8)) }

        await m.refreshLive(session: StubURLProtocol.session())
        XCTAssertEqual(m.state.entries[0].lastReading, 2.5, accuracy: 0.0001)
        XCTAssertNil(m.state.entries[0].lastCumulative, "a rate needs no baseline")
    }

    /// A counter that resets between reads must not produce a negative rate.
    func testAResetCounterRebasesInsteadOfGoingNegative() async throws {
        let keysURL = try isolate()
        defer { restore(keysURL) }

        StubURLProtocol.reset()
        defer { StubURLProtocol.reset() }

        var now = Date()
        let m = model()
        m.clock = { now }
        m.addKey(name: "OpenAI prod", provider: "openai", cap: 5)
        // The provider's URL is not one we can reach, so drive it through the
        // custom source with the same counting-up behaviour.
        m.setSource(keyID: m.state.entries[0].id, spendUrl: "https://example.com/cost.json",
                    jsonPath: "total", header: nil, measures: "total")
        // A watched OpenAI key with no key pasted is a different failure, so give
        // it one: this test is about what the number does, not the key.
        Credentials.set("sk-admin-test", for: "openai")

        var total = 50.0
        StubURLProtocol.responder = { _ in (200, Data("{\"total\": \(total)}".utf8)) }

        await m.refreshLive(session: StubURLProtocol.session())
        total = 51
        now = now.addingTimeInterval(3600)
        await m.refreshLive(session: StubURLProtocol.session())
        XCTAssertEqual(m.state.entries[0].lastReading, 1.0, accuracy: 0.0001)

        // Yesterday's total rolls over to today's.
        now = now.addingTimeInterval(3600)
        total = 2
        await m.refreshLive(session: StubURLProtocol.session())

        XCTAssertEqual(m.state.entries[0].readings.count, 1,
                       "a negative rate must never be recorded")
        XCTAssertEqual(m.state.entries[0].lastReading, 1.0, accuracy: 0.0001,
                       "the last honest rate stands until there is a new one")
        XCTAssertEqual(m.state.entries[0].lastCumulative ?? 0, 2, accuracy: 0.0001)
    }
    /// What the endpoints and the key kind have to do with each other, in the
    /// message a person actually reads.
    func testARejectedKeySaysSoRatherThanBlamingTheAddress() async throws {
        let keysURL = try isolate()
        defer { restore(keysURL) }

        StubURLProtocol.reset()
        defer { StubURLProtocol.reset() }

        let m = model()
        m.addKey(name: "OpenRouter", provider: "openrouter", cap: 5)
        // A key exists and the provider turns it down — which is not the same
        // thing as never having pasted one.
        Credentials.set("sk-or-bad", for: "openrouter")
        StubURLProtocol.responder = { _ in (401, Data()) }

        await m.refreshLive(session: StubURLProtocol.session())
        XCTAssertNil(m.state.entries[0].lastCumulative, "a failed read changes nothing")
        XCTAssertTrue(m.lastReadMessage?.contains("not valid") ?? false, m.lastReadMessage ?? "")
        XCTAssertTrue(m.lastReadMessage?.contains("Settings") ?? false, m.lastReadMessage ?? "")
    }

    /// A provider with no public spend endpoint must never be a dead end.
    func testAProviderWithoutAnEndpointPointsAtTheManualPath() async throws {
        let keysURL = try isolate()
        defer { restore(keysURL) }

        let m = model()
        m.addKey(name: "Groq", provider: "groq", cap: 5)
        await m.refreshLive(session: StubURLProtocol.session())

        XCTAssertFalse(m.lastReadMessage?.isEmpty ?? true)
        // Nothing at all is set up, so the app says what to do instead.
        XCTAssertTrue(m.lastReadMessage?.contains("Log a reading") ?? false, m.lastReadMessage ?? "")
    }

    /// A custom source has to survive the state file, header and counter kind
    /// included, or a restart quietly undoes it.
    func testACustomSourceRoundTripsThroughTheStateFile() {
        let m = model()
        let key = m.addKey(name: "Custom", provider: "custom", cap: 3,
                           spendUrl: "https://example.com/cost.json", jsonPath: "data.total",
                           header: "x-api-key", measures: "total")

        let reloaded = AppModel.read(from: m.stateURL)
        let source = reloaded.entries.first?.source
        XCTAssertEqual(source?.spendUrl, "https://example.com/cost.json")
        XCTAssertEqual(source?.jsonPath, "data.total")
        XCTAssertEqual(source?.header, "x-api-key")
        XCTAssertEqual(source?.measures, "total")
        XCTAssertEqual(key.source?.measures, "total")
    }

    /// A provider that claims a live read must actually have an endpoint to
    /// read. `custom` is the exception: the user supplies its address.
    func testEveryProviderClaimingALiveReadCanActuallyBeRead() {
        for provider in Providers.all where provider.supportsLiveSpend {
            guard provider.id != "custom" else { continue }
            let key = BurnKey(id: provider.id, name: provider.id, provider: provider.id)
            XCTAssertNotNil(SpendSource.endpoint(for: key),
                            "\(provider.id) says it can be read live but has no endpoint")
        }
    }

    /// A provider without a live read must never look broken or refused: it has
    /// to say what to do instead.
    func testEveryProviderWithoutALiveReadIsExplainedNotRefused() {
        for provider in Providers.all where !provider.supportsLiveSpend {
            let key = BurnKey(id: provider.id, name: provider.id, provider: provider.id)
            XCTAssertFalse(SpendSource.canReadLive(key))
            XCTAssertFalse(provider.keyHint.isEmpty, "\(provider.id) must say what to do instead")
        }
    }

    func testTheLiveProvidersAreTheOnesWithAnEndpointToRead() {
        // The settings rows are generated from this flag, so it must not drift
        // from what the fetcher can actually reach.
        let live = Set(Providers.all.filter(\.supportsLiveSpend).map(\.id))
        XCTAssertEqual(live, ["openai", "anthropic", "openrouter", "custom"])
    }

    func testAProviderWeDoNotKnowIsDescribedAsItself() {
        // Not quietly renamed to "Custom endpoint" and pointed at a form that
        // will not help.
        let provider = Providers.provider(for: "mistral")
        XCTAssertEqual(provider.label, "Mistral")
        XCTAssertEqual(Providers.label(for: "mistral"), "Mistral",
                       "both ways of naming a provider must agree")
        XCTAssertFalse(provider.supportsLiveSpend)
    }

    // MARK: - Test connection

    /// The answer to "I pasted my key and nothing happened". A test reads and
    /// reports, and must leave every burn figure exactly where it was.
    func testATestSaysItWorksAndRecordsNothing() async throws {
        let keysURL = try isolate()
        defer { restore(keysURL) }

        StubURLProtocol.reset()
        defer { StubURLProtocol.reset() }

        let m = model()
        m.addKey(name: "OpenRouter", provider: "openrouter", cap: 5)
        Credentials.set("sk-or-1", for: "openrouter")
        StubURLProtocol.responder = { _ in (200, Data(#"{"data":{"usage":4.25}}"#.utf8)) }

        await m.testCredential("openrouter", session: StubURLProtocol.session())

        let test = try XCTUnwrap(m.keyTests["openrouter"])
        XCTAssertTrue(test.isWorking, "\(test)")
        guard case .working(let message) = test else { return XCTFail("not working") }
        XCTAssertTrue(message.contains("Works"), message)
        XCTAssertTrue(message.contains("4.25"), message)

        // A test is not a reading.
        XCTAssertEqual(m.state.entries[0].lastReading, 0, accuracy: 0.0001)
        XCTAssertNil(m.state.entries[0].lastCumulative)
        XCTAssertTrue(m.state.entries[0].readings.isEmpty)
    }

    /// A failed test carries the provider's own reason, not "it did not work".
    func testATestReportsTheProvidersOwnReason() async throws {
        let keysURL = try isolate()
        defer { restore(keysURL) }

        StubURLProtocol.reset()
        defer { StubURLProtocol.reset() }

        let m = model()
        Credentials.set("sk-ant-api03-x", for: "anthropic")
        StubURLProtocol.responder = { _ in (401, Data()) }

        await m.testCredential("anthropic", session: StubURLProtocol.session())

        let test = try XCTUnwrap(m.keyTests["anthropic"])
        guard case .failed(let message) = test else { return XCTFail("expected failed, got \(test)") }
        XCTAssertTrue(message.contains("Admin key"), message)
        XCTAssertTrue(message.contains("individual accounts"), message)
    }

    func testATestWithNoKeySaysSoRatherThanReading() async throws {
        let keysURL = try isolate()
        defer { restore(keysURL) }

        let m = model()
        await m.testCredential("openai", session: StubURLProtocol.session())

        let test = try XCTUnwrap(m.keyTests["openai"])
        guard case .failed(let message) = test else { return XCTFail("expected failed, got \(test)") }
        XCTAssertTrue(message.contains("No key stored yet"), message)
    }

    /// A provider with no live read is explained, never left looking broken.
    func testATestForAProviderWithNoEndpointExplainsItself() async throws {
        let keysURL = try isolate()
        defer { restore(keysURL) }

        let m = model()
        Credentials.set("gsk-abc", for: "groq")
        await m.testCredential("groq", session: StubURLProtocol.session())

        let test = try XCTUnwrap(m.keyTests["groq"])
        guard case .failed(let message) = test else { return XCTFail("expected failed, got \(test)") }
        XCTAssertTrue(message.contains("no live spend read"), message)
    }

    /// A custom endpoint has no address until a watched key supplies one, so
    /// the honest answer is to say what to do first.
    func testATestForCustomWithoutAURLPointsAtTheWatchedKey() async throws {
        let keysURL = try isolate()
        defer { restore(keysURL) }

        let m = model()
        await m.testCredential("custom", session: StubURLProtocol.session())

        let test = try XCTUnwrap(m.keyTests["custom"])
        guard case .failed(let message) = test else { return XCTFail("expected failed, got \(test)") }
        XCTAssertTrue(message.contains("cost URL"), message)
    }

    /// With a watched custom key set up, its address is what gets tested.
    func testATestForCustomUsesTheWatchedKeysAddress() async throws {
        let keysURL = try isolate()
        defer { restore(keysURL) }

        StubURLProtocol.reset()
        defer { StubURLProtocol.reset() }

        let m = model()
        m.addKey(name: "Custom", provider: "custom", cap: 3,
                 spendUrl: "https://example.com/cost.json", jsonPath: "total", measures: "rate")
        StubURLProtocol.responder = { _ in (200, Data(#"{"total":2.5}"#.utf8)) }

        await m.testCredential("custom", session: StubURLProtocol.session())

        let test = try XCTUnwrap(m.keyTests["custom"])
        XCTAssertTrue(test.isWorking, "\(test)")
    }

    /// Someone who pastes a key and presses Test means "try this one", so the
    /// field is honoured — and still not saved, because Test only reads.
    func testATestUsesTheKeyInTheFieldBeforeItIsSaved() async throws {
        let keysURL = try isolate()
        defer { restore(keysURL) }

        StubURLProtocol.reset()
        defer { StubURLProtocol.reset() }

        let m = model()
        var sentAuth: String?
        StubURLProtocol.responder = { request in
            sentAuth = request.value(forHTTPHeaderField: "Authorization")
            return (200, Data(#"{"data":{"usage":1.5}}"#.utf8))
        }

        // Pasted with the usual junk still attached, as a real paste arrives.
        await m.testCredential("openrouter", using: "  \"Bearer sk-or-draft-1\"  ",
                               session: StubURLProtocol.session())

        let test = try XCTUnwrap(m.keyTests["openrouter"])
        XCTAssertTrue(test.isWorking, "\(test)")
        XCTAssertEqual(sentAuth, "Bearer sk-or-draft-1", "the pasted key is what gets tried")
        XCTAssertNil(Credentials.key(for: "openrouter"), "a test must never save the key")
    }

    /// The poll path must not tell someone their key is bad when they simply
    /// have not pasted one yet — the exact confusion Phase 3 exists to remove.
    func testAPollWithNoKeySaysSoRatherThanBlamingTheKey() async throws {
        let keysURL = try isolate()
        defer { restore(keysURL) }

        StubURLProtocol.reset()
        defer { StubURLProtocol.reset() }

        let m = model()
        m.addKey(name: "OpenAI prod", provider: "openai", cap: 5)
        await m.refreshLive(session: StubURLProtocol.session())

        XCTAssertTrue(m.lastReadMessage?.contains("No OpenAI key stored yet") ?? false, m.lastReadMessage ?? "")
        XCTAssertFalse(m.lastReadMessage?.contains("not valid") ?? true, m.lastReadMessage ?? "")
    }
}

import XCTest
import Foundation
@testable import BurnFuseUI

/// A provider that counts money up needs two reads before it says anything
/// useful. These lock that down: the running total must never be mistaken for
/// an hourly rate, and a counter that resets must never become a negative one.
final class CumulativeTests: XCTestCase {

    private let hour = 3_600_000.0
    private let fiveMinutes = 300_000.0

    // MARK: - The maths

    private func assertHours(_ result: BurnRate, _ expected: Double, file: StaticString = #filePath, line: UInt = #line) {
        guard case .hours(let rate) = result else {
            return XCTFail("expected \(expected) dollars per hour, got \(result)", file: file, line: line)
        }
        XCTAssertEqual(rate, expected, accuracy: 0.0001, file: file, line: line)
    }

    func testTheFirstReadIsABaselineOnly() {
        let key = BurnKey(id: "k", name: "k", provider: "openai")
        XCTAssertEqual(key.burnRate(fromCumulative: 100, at: 0), .unmeasured)
    }

    func testTwoReadsAnHourApartGiveAnHourlyRate() {
        let key = BurnKey(id: "k", name: "k", provider: "openai", lastCumulative: 100, lastCumulativeAt: 0)
        assertHours(key.burnRate(fromCumulative: 103, at: hour), 3)
    }

    func testTheRateScalesWithTheGapBetweenReads() {
        // A dollar in five minutes is twelve dollars an hour. This is the whole
        // reason a short gap must not be reported as a tiny rate.
        let key = BurnKey(id: "k", name: "k", provider: "openai", lastCumulative: 100, lastCumulativeAt: 0)
        assertHours(key.burnRate(fromCumulative: 101, at: fiveMinutes), 12)
    }

    func testAQuietProviderReportsNoBurn() {
        let key = BurnKey(id: "k", name: "k", provider: "openai", lastCumulative: 100, lastCumulativeAt: 0)
        assertHours(key.burnRate(fromCumulative: 100, at: hour), 0)
    }

    func testAResetCounterIsNotANegativeRate() {
        // A billing day rolling over looks like spend going backwards. Say so,
        // rather than recording a rate of minus fifty dollars an hour.
        let key = BurnKey(id: "k", name: "k", provider: "openai", lastCumulative: 52, lastCumulativeAt: 0)
        XCTAssertEqual(key.burnRate(fromCumulative: 2, at: hour), .rebased)
    }

    func testTwoReadsInTheSameInstantMeanNothing() {
        let key = BurnKey(id: "k", name: "k", provider: "openai", lastCumulative: 100, lastCumulativeAt: 5)
        XCTAssertEqual(key.burnRate(fromCumulative: 100, at: 5), .unmeasured)
    }

    func testTheBaselineSurvivesAStateRoundTrip() {
        let key = BurnKey(id: "k", name: "k", provider: "openai", lastCumulative: 42.5, lastCumulativeAt: 1234)
        let decoded = try? JSONDecoder().decode(BurnKey.self, from: JSONEncoder().encode(key))
        XCTAssertEqual(decoded?.lastCumulative ?? 0, 42.5, accuracy: 0.0001)
        XCTAssertEqual(decoded?.lastCumulativeAt ?? 0, 1234)
    }

    func testAKeyFromAnOlderStateFileHasNoBaseline() {
        // Files written before this feature have no sample, and must decode
        // rather than fail.
        let json = #"{"id":"k","name":"K","provider":"openai","readings":[]}"#
        let key = try? JSONDecoder().decode(BurnKey.self, from: Data(json.utf8))
        XCTAssertNil(key?.lastCumulative)
        XCTAssertEqual(key.map { $0.burnRate(fromCumulative: 5, at: 1) }, .unmeasured)
    }
}

/// Warns about a key that is the wrong kind before it costs a failed read —
/// and stays quiet about everything it is not sure about.
final class KeyShapeTests: XCTestCase {

    func testAnOpenAIProjectKeyIsFlaggedAsTheWrongKind() {
        let verdict = KeyShape.check("sk-proj-abc123", for: "openai")
        XCTAssertEqual(verdict.severity, .warning)
        XCTAssertTrue(verdict.message?.contains("Admin") ?? false)
    }

    func testAnOpenAIAdminKeyIsLeftAlone() {
        XCTAssertEqual(KeyShape.check("sk-admin-abc123", for: "openai"), KeyShape.fine)
    }

    func testAnOpenAIKeyPastedIntoTheOpenRouterRowIsFlagged() {
        let verdict = KeyShape.check("sk-admin-abc123", for: "openrouter")
        XCTAssertEqual(verdict.severity, .warning)
        XCTAssertTrue(verdict.message?.contains("sk-or-") ?? false)
    }

    func testAnOpenRouterKeyIsLeftAlone() {
        XCTAssertEqual(KeyShape.check("sk-or-v1-abc123", for: "openrouter"), KeyShape.fine)
    }

    func testAStandardAnthropicKeyIsFlagged() {
        XCTAssertEqual(KeyShape.check("sk-ant-api03-abc", for: "anthropic").severity, .warning)
        XCTAssertEqual(KeyShape.check("sk-ant-admin01-abc", for: "anthropic"), KeyShape.fine)
    }

    func testAnEmptyFieldIsNeverAMistake() {
        XCTAssertEqual(KeyShape.check("", for: "openai"), KeyShape.fine)
        XCTAssertEqual(KeyShape.check("   ", for: "openai"), KeyShape.fine)
    }

    /// Guessing wrong teaches people to ignore the warning, so anything
    /// unrecognised stays quiet — the provider has the last word.
    func testAnUnrecognisedKeyIsLeftAlone() {
        XCTAssertEqual(KeyShape.check("totally-made-up-key", for: "openai"), KeyShape.fine)
        XCTAssertEqual(KeyShape.check("sk-admin-abc", for: "custom"), KeyShape.fine)
        XCTAssertEqual(KeyShape.check("anything", for: "groq"), KeyShape.fine)
    }

    func testTheCheckLooksPastPasteJunk() {
        XCTAssertEqual(KeyShape.check("\"Bearer sk-proj-abc\"", for: "openai").severity, .warning)
    }

    /// The second most common reason a pasted key "does not work": it is the
    /// stand-in from a `.env.example` or a doc snippet, copied verbatim.
    func testThePlaceholderFromASampleFileIsNamedForWhatItIs() {
        for placeholder in [
            "your_openrouter_api_key_here",
            "your_api_key",
            "<YOUR_OPENAI_ADMIN_KEY>",
            "sk-or-v1-...",
            "sk-xxxxxxxxxxxxxxxx",
            "changeme",
            "REPLACE_ME",
        ] {
            let verdict = KeyShape.check(placeholder, for: "openrouter")
            XCTAssertEqual(verdict.severity, .warning, placeholder)
            XCTAssertTrue(verdict.message?.contains("placeholder") ?? false, "\(placeholder): \(verdict.message ?? "")")
        }
    }

    /// A warning on a good key is worse than no warning, so real shapes stay
    /// quiet even though they are long and made-up looking.
    func testARealLookingKeyIsNotMistakenForAPlaceholder() {
        XCTAssertEqual(KeyShape.check("sk-or-v1-0123456789abcdef0123456789abcdef", for: "openrouter"), KeyShape.fine)
        XCTAssertEqual(KeyShape.check("sk-ant-admin01-abcDEF123", for: "anthropic"), KeyShape.fine)
        XCTAssertEqual(KeyShape.check("gsk_0123456789abcdef", for: "groq"), KeyShape.fine)
    }
}

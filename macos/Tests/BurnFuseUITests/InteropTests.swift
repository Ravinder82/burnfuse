import XCTest
import Foundation
@testable import BurnFuseUI

/// Guards the contract that matters most: the CLI and the macOS app read and
/// write the same file. `cli-state.json` is real output from
/// `burnfuse demo && burnfuse record`.
final class InteropTests: XCTestCase {

    private func fixtureURL(_ name: String) throws -> URL {
        let bundle = Bundle.module
        return try XCTUnwrap(
            bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
                ?? bundle.url(forResource: name, withExtension: "json"),
            "fixture \(name).json missing from the test bundle"
        )
    }

    func testDecodesRealCLIStateFile() throws {
        let url = try fixtureURL("cli-state")
        let data = try Data(contentsOf: url)
        let state = try JSONDecoder().decode(AppState.self, from: data)

        XCTAssertEqual(state.version, 2)
        XCTAssertEqual(state.entries.count, 3, "three seeded keys")
        XCTAssertEqual(state.incidents.count, 1, "one trip was recorded")
        XCTAssertEqual(state.tripped.map(\.name), ["OpenAI prod"])
        XCTAssertEqual(state.settings.zThreshold, 2.5)
        XCTAssertEqual(state.settings.notifyWebhook, "https://hooks.slack.com/services/T/B/X")

        // The tripped key kept its history and its cap.
        let tripped = try XCTUnwrap(state.tripped.first)
        XCTAssertEqual(tripped.hourlyLimit, 5)
        XCTAssertEqual(tripped.lastReading, 9.90, accuracy: 0.001)
        XCTAssertGreaterThan(tripped.readings.count, 5)
    }

    func testReEncodingKeepsEveryFieldTheCLIUses() throws {
        let url = try fixtureURL("cli-state")
        let original = try JSONDecoder().decode(AppState.self, from: Data(contentsOf: url))

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let roundTripped = try JSONDecoder().decode(AppState.self, from: encoder.encode(original))

        XCTAssertEqual(roundTripped.entries.map(\.id), original.entries.map(\.id))
        XCTAssertEqual(roundTripped.entries.map(\.status), original.entries.map(\.status))
        XCTAssertEqual(roundTripped.settings.notifyWebhook, original.settings.notifyWebhook)
        XCTAssertEqual(roundTripped.incidents.count, original.incidents.count)
        for (a, b) in zip(roundTripped.entries, original.entries) {
            XCTAssertEqual(a.readings.count, b.readings.count)
            XCTAssertEqual(a.lastReading, b.lastReading, accuracy: 0.0001)
        }
    }

    func testCLIFileIsAcceptedByModelWithoutLoss() throws {
        let url = try fixtureURL("cli-state")
        let copy = FileManager.default.temporaryDirectory
            .appendingPathComponent("burnfuse-interop-\(UUID().uuidString).json")
        try FileManager.default.copyItem(at: url, to: copy)
        try MainActor.assumeIsolated {
            let model = AppModel(stateURL: copy, pollInterval: 0)
            XCTAssertEqual(model.state.entries.count, 3)
            XCTAssertTrue(model.state.hasBreach)
            XCTAssertEqual(model.statusSummary, "1 tripped")
            XCTAssertTrue(model.headline.contains("OpenAI prod"))
        }
    }

    func testFixtureIsTheExactShapeTheCLIWrites() throws {
        // Version, settings and per-entry fields the CLI depends on.
        let url = try fixtureURL("cli-state")
        let data = try Data(contentsOf: url)
        let state = try JSONDecoder().decode(AppState.self, from: data)
        XCTAssertEqual(state.version, 2)

        let tripped = try XCTUnwrap(state.tripped.first)
        XCTAssertEqual(tripped.status, "tripped")
        XCTAssertNotNil(tripped.trippedAt, "a tripped key records when it happened")

        let incident = try XCTUnwrap(state.incidents.first)
        XCTAssertEqual(incident.entryId, tripped.id)
        XCTAssertEqual(incident.reason, "over cap")
        XCTAssertEqual(incident.action, "tripped")
        XCTAssertGreaterThan(incident.at, 0)
    }

    func testUnknownFieldsDoNotBreakDecoding() throws {
        let json = """
        {
          "version": 2,
          "historyWindow": 12,
          "somethingNew": {"a": 1},
          "settings": {"zThreshold": 3.0, "futureField": true},
          "entries": [
            {"id": "x", "name": "X", "hourlyLimit": 2, "readings": [], "brandNew": 7}
          ],
          "incidents": []
        }
        """
        let state = try JSONDecoder().decode(AppState.self, from: Data(json.utf8))
        XCTAssertEqual(state.settings.zThreshold, 3.0)
        XCTAssertEqual(state.settings.historyWindow, 24, "falls back to the default")
        XCTAssertEqual(state.entries.first?.name, "X")
    }

    func testMissingOptionalFieldsUseSaneDefaults() throws {
        let json = #"{"entries":[{"name":"Bare"}],"settings":{}}"#
        let state = try JSONDecoder().decode(AppState.self, from: Data(json.utf8))
        let key = try XCTUnwrap(state.entries.first)
        XCTAssertEqual(key.hourlyLimit, 5)
        XCTAssertTrue(key.armed)
        XCTAssertEqual(key.status, "armed")
        XCTAssertEqual(state.settings.minStdDev, 0.1)
    }
}
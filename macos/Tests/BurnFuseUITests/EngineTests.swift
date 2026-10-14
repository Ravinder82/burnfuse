import XCTest
@testable import BurnFuseUI

final class EngineTests: XCTestCase {

    func testBaselineIgnoresCurrentReading() {
        let key = BurnKey(id: "k", name: "k", hourlyLimit: 100,
                          readings: [1, 1, 1].map { Reading(at: 0, cost: $0) },
                          lastReading: 50)
        let a = BurnEngine.assess(key, settings: Settings())
        XCTAssertEqual(a.baseline, 1, accuracy: 0.0001)
        XCTAssertTrue(a.spike)
        XCTAssertTrue(a.breach)
    }

    func testQuietKeyDoesNotFalseTrip() {
        let key = BurnKey(id: "k", name: "k", hourlyLimit: 100,
                          readings: [1, 1, 1, 1].map { Reading(at: 0, cost: $0) },
                          lastReading: 1.05)
        let a = BurnEngine.assess(key, settings: Settings(minStdDev: 0.1))
        XCTAssertFalse(a.breach, "z was \(a.z)")
    }

    func testOverCapTripsWithoutSpike() {
        let key = BurnKey(id: "k", name: "k", hourlyLimit: 5,
                          readings: [4.9, 4.9, 4.9].map { Reading(at: 0, cost: $0) },
                          lastReading: 5.5)
        let a = BurnEngine.assess(key, settings: Settings())
        XCTAssertTrue(a.overCap)
        XCTAssertTrue(a.breach)
    }

    func testFirstReadingNeverTripsOnSpikeAlone() {
        let key = BurnKey(id: "k", name: "k", hourlyLimit: 100, readings: [], lastReading: 40)
        let a = BurnEngine.assess(key, settings: Settings())
        XCTAssertFalse(a.spike)
        XCTAssertFalse(a.breach)
    }

    func testRecordReadingTripsAndLogsIncident() {
        var state = AppState()
        let key = BurnEngine.addKey(&state, name: "OpenAI prod", provider: "openai", cap: 5)
        for cost in [1.1, 1.2, 1.15, 1.3, 1.25] {
            state.entries[0].readings.append(Reading(at: 0, cost: cost))
        }
        state.entries[0].lastReading = 1.25

        let incident = BurnEngine.recordReading(&state, keyID: key.id, cost: 9.9)
        XCTAssertNotNil(incident)
        XCTAssertEqual(state.entries[0].status, "tripped")
        XCTAssertEqual(state.incidents.count, 1)
        XCTAssertEqual(incident?.reason, "over cap")
    }

    func testTripAndArmCycle() {
        var state = AppState()
        let key = BurnEngine.addKey(&state, name: "k", provider: "custom", cap: 5)
        BurnEngine.trip(&state, keyID: key.id)
        XCTAssertTrue(state.entries[0].isTripped)
        XCTAssertFalse(state.entries[0].armed)

        BurnEngine.arm(&state, keyID: key.id, clearHistory: true)
        XCTAssertFalse(state.entries[0].isTripped)
        XCTAssertTrue(state.entries[0].readings.isEmpty)
    }

    func testAvertedIsPositiveAndBounded() {
        let incident = Incident(entryId: "k", name: "k", reading: 10, hourlyLimit: 5, z: 3, reason: "spike", action: "tripped")
        XCTAssertEqual(BurnEngine.averted(incident), 40, accuracy: 0.001)
    }

    func testCombinedSeriesSumsAcrossKeys() {
        var state = AppState()
        state.entries = [
            BurnKey(id: "a", name: "a", readings: [Reading(at: 0, cost: 1), Reading(at: 1, cost: 2)], lastReading: 2),
            BurnKey(id: "b", name: "b", readings: [Reading(at: 0, cost: 3), Reading(at: 1, cost: 4)], lastReading: 4),
        ]
        let series = BurnEngine.combinedSeries(state)
        XCTAssertEqual(series, [4, 6])
    }

    func testMakeIDIsSluggedAndUnique() {
        let a = BurnEngine.makeID(seed: "OpenAI Prod!")
        XCTAssertTrue(a.hasPrefix("openai_prod"))
        XCTAssertNotEqual(a, BurnEngine.makeID(seed: "OpenAI Prod!"))
    }

    func testFmtFormatsMoneyAndSigma() {
        XCTAssertEqual(Fmt.money(1.5), "$1.50")
        XCTAssertEqual(Fmt.sigma(2.456), "+2.46σ")
        XCTAssertEqual(Fmt.multiple(4, 2), "2.0×")
    }
}

@MainActor
final class AppModelTests: XCTestCase {

    func makeModel() -> AppModel {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("burnfuse-test-\(UUID().uuidString).json")
        return AppModel(stateURL: url, pollInterval: 0)
    }

    func testAddAndPersistRoundTrips() {
        let model = makeModel()
        model.addKey(name: "Test key", provider: "openai", cap: 7)
        let reloaded = AppModel.read(from: model.stateURL)
        XCTAssertEqual(reloaded.entries.count, 1)
        XCTAssertEqual(reloaded.entries.first?.hourlyLimit, 7)
        XCTAssertEqual(reloaded.entries.first?.name, "Test key")
    }

    func testRecordTripsAndSetsHeadline() {
        let model = makeModel()
        let key = model.addKey(name: "Burner", provider: "custom", cap: 2)
        for cost in [0.4, 0.5, 0.45, 0.48] { model.record(keyID: key.id, cost: cost) }
        model.record(keyID: key.id, cost: 12)
        XCTAssertTrue(model.state.hasBreach)
        XCTAssertEqual(model.state.tripped.first?.name, "Burner")
        XCTAssertTrue(model.headline.contains("Burner"))
    }

    func testTripAllAndArmAll() {
        let model = makeModel()
        model.addKey(name: "A", provider: "custom", cap: 5)
        model.addKey(name: "B", provider: "custom", cap: 5)
        model.tripAll()
        XCTAssertEqual(model.state.tripped.count, 2)
        model.armAll(clearHistory: true)
        XCTAssertEqual(model.state.tripped.count, 0)
    }

    func testInMemoryRendersPersistPath() {
        let model = makeModel()
        XCTAssertTrue(model.stateURL.path.contains("burnfuse-test-"))
    }
}
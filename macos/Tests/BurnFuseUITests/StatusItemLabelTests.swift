import XCTest
import SwiftUI
@testable import BurnFuseUI

/// The menu-bar colour block is a promise: the colour tells you the state before
/// you read the number. These lock that behaviour so it cannot drift.
@MainActor
final class StatusItemLabelTests: XCTestCase {

    private func model(_ mutate: (AppModel) -> Void = { _ in }) -> AppModel {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("burnfuse-status-\(UUID().uuidString).json")
        let model = AppModel(stateURL: url, pollInterval: 0)
        model.seedDemoData()
        mutate(model)
        return model
    }

    // MARK: - Fraction

    func testFractionIsZeroWithoutCaps() {
        XCTAssertEqual(model().burnFraction >= 0, true)
        let empty = model { for key in $0.state.entries { $0.remove(keyID: key.id) } }
        XCTAssertEqual(empty.burnFraction, 0, "no caps means no fraction, never a divide by zero")
    }

    func testFractionIsBurnOverCap() {
        let m = model { m in
            for key in m.state.entries { m.setCap(keyID: key.id, cap: 10) }
            if let first = m.state.entries.first {
                m.record(keyID: first.id, cost: 5)
            }
        }
        // Caps are 10+10+10 = 30; total burn is 5 plus the two seed readings.
        let expected = m.state.totalBurn / m.state.totalCap
        XCTAssertEqual(m.burnFraction, expected, accuracy: 0.0001)
    }

    func testFractionClampsToOneWhenOverCap() {
        let m = model { m in
            for key in m.state.entries { m.setCap(keyID: key.id, cap: 0.01) }
        }
        XCTAssertEqual(m.burnFraction, 1.0, accuracy: 0.0001)
    }

    // MARK: - The colour ramp

    /// Compare two colours by their resolved components so we can make claims
    /// like "this one is greener than that one".
    private func components(_ color: Color) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? NSColor.black
        return (ns.redComponent, ns.greenComponent, ns.blueComponent)
    }

    func testRampGetsHotterAsBurnRises() {
        let cool = components(StatusItemLabel.blockColour(forFraction: 0.0))
        let warm = components(StatusItemLabel.blockColour(forFraction: 0.55))
        let hot = components(StatusItemLabel.blockColour(forFraction: 1.0))

        // Warmth = red minus green. It should climb the whole way up the ramp.
        let warmth = { (c: (r: CGFloat, g: CGFloat, b: CGFloat)) in c.r - c.g }

        XCTAssertGreaterThan(cool.g, cool.r, "settled burn should read green")
        XCTAssertGreaterThan(warmth(warm), warmth(cool), "climbing burn should be warmer than settled")
        XCTAssertGreaterThan(warmth(hot), warmth(warm), "near-cap burn should be warmer than climbing")
        XCTAssertLessThan(hot.g, warm.g, "and carry less green")
    }

    func testRampIsContinuousAndClamped() {
        // Nothing above 1 or below 0 should change the colour.
        let atOne = components(StatusItemLabel.blockColour(forFraction: 1.0))
        let overOne = components(StatusItemLabel.blockColour(forFraction: 4.0))
        XCTAssertEqual(atOne.r, overOne.r, accuracy: 0.001)
        XCTAssertEqual(atOne.g, overOne.g, accuracy: 0.001)

        let atZero = components(StatusItemLabel.blockColour(forFraction: 0.0))
        let belowZero = components(StatusItemLabel.blockColour(forFraction: -2.0))
        XCTAssertEqual(atZero.r, belowZero.r, accuracy: 0.001)
        XCTAssertEqual(atZero.g, belowZero.g, accuracy: 0.001)
    }

    // MARK: - The whole item

    func testLabelRendersForEveryState() {
        // Not a pixel test — just that each state can build a view without
        // trapping, which is what a bad state combination would do.
        let empty = model { m in for key in m.state.entries { m.remove(keyID: key.id) } }
        let settled = model()
        let tripped = model { $0.tripAll() }

        for m in [empty, settled, tripped] {
            XCTAssertNotNil(NSHostingView(rootView: StatusItemLabel(model: m)).fittingSize)
        }
    }
}
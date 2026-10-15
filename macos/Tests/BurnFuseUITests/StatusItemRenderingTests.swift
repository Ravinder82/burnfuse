import XCTest
import AppKit
import SwiftUI
@testable import BurnFuseUI

/// Guards against the bug that made the menu-bar item render as a plain white
/// glyph: the colour block must survive a round-trip through a bitmap as a
/// non-template image with real colour in it.
@MainActor
final class StatusItemRenderingTests: XCTestCase {

    private func render(_ view: some View) -> NSImage? {
        let hosting = NSHostingView(rootView: view)
        hosting.layoutSubtreeIfNeeded()
        let size = hosting.fittingSize
        guard size.width > 0, size.height > 0 else { return nil }
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()
        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return nil }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        let image = NSImage(size: size)
        image.addRepresentation(rep)
        return image
    }

    private func demo() -> AppModel {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("burnfuse-render-\(UUID().uuidString).json")
        return sampleModel(at: url)
    }

    /// The whole point of the direct `NSStatusItem` is that the drawn colour
    /// reaches the screen. Sample the centre of the capsule and assert it is
    /// actually green, not greyscale.
    func testColourBlockRendersInColour() throws {
        let model = demo()
        let image = try XCTUnwrap(render(StatusItemLabel(model: model).padding(2)))
        let rep = try XCTUnwrap(NSBitmapImageRep(data: image.tiffRepresentation ?? Data()))
        rep.size = image.size

        // Sample a band across the middle of the item and look for a pixel that
        // is clearly green — that is the capsule fill.
        let midY = rep.pixelsHigh / 2
        var foundGreen = false
        for x in 0..<rep.pixelsWide {
            guard let c = rep.colorAt(x: x, y: midY) else { continue }
            let r = c.redComponent, g = c.greenComponent, b = c.blueComponent
            if g > 0.5, g > r + 0.15, g > b + 0.15 { foundGreen = true; break }
        }
        XCTAssertTrue(foundGreen, "the settled colour block should render green, not greyscale")
    }

    /// A tripped item must render red, so the alert state is unmistakable.
    func testBreachedBlockRendersRed() throws {
        let model = demo()
        model.tripAll()
        let image = try XCTUnwrap(render(StatusItemLabel(model: model).padding(2)))
        let rep = try XCTUnwrap(NSBitmapImageRep(data: image.tiffRepresentation ?? Data()))
        rep.size = image.size

        let midY = rep.pixelsHigh / 2
        var foundRed = false
        for x in 0..<rep.pixelsWide {
            guard let c = rep.colorAt(x: x, y: midY) else { continue }
            let r = c.redComponent, g = c.greenComponent, b = c.blueComponent
            if r > 0.5, r > g + 0.25, r > b + 0.25 { foundRed = true; break }
        }
        XCTAssertTrue(foundRed, "a tripped colour block should render red")
    }

    /// The label must always draw something with real size, or the menu bar
    /// would show a zero-width item.
    func testLabelHasNonZeroSize() {
        for tripped in [false, true] {
            let model = demo()
            if tripped { model.tripAll() }
            let hosting = NSHostingView(rootView: StatusItemLabel(model: model))
            hosting.layoutSubtreeIfNeeded()
            let size = hosting.fittingSize
            XCTAssertGreaterThan(size.width, 20, "tripped: \(tripped)")
            XCTAssertGreaterThan(size.height, 10, "tripped: \(tripped)")
        }
    }
}
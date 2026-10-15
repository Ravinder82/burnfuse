import XCTest
import AppKit
import SwiftUI
@testable import BurnFuseUI

/// The identity system — the tile and the colour that make a row say "this is
/// the fal key" before anyone reads the fine print.
///
/// What is worth testing here is not that a colour exists: it is that the colour
/// is *stable* (an id must not change colour between launches, or the cue is a
/// lie), *distinct* between providers a person sees next to each other, and
/// actually painted — not another greyscale glyph that looks like the bug this
/// replaced.
@MainActor
final class IdentityTests: XCTestCase {

    // MARK: - Colour rules

    func testTintIsStableForAnyIdIncludingOnesWeDoNotKnow() {
        // A provider BurnFuse has never heard of still has to keep its colour.
        for id in ["openai", "some-startup-2027", "", "custom"] {
            XCTAssertEqual(Providers.tint(for: id), Providers.tint(for: id),
                           "\(id) changed colour between calls")
        }
    }

    func testEveryProviderInTheCatalogueHasATint() {
        for provider in Providers.all {
            let tint = Providers.tint(for: provider)
            XCTAssertNotNil(tint, "\(provider.id) has no colour")
        }
    }

    /// The cue that matters most: two providers a person is likely to have can
    /// never wear the same colour, so "the blue one" is never ambiguous.
    func testTheLiveProvidersAreAllDifferentColours() {
        let live = ["openrouter", "openai", "anthropic"]
        for (a, b) in pairs(live) {
            XCTAssertNotEqual(Providers.tint(for: a), Providers.tint(for: b),
                              "\(a) and \(b) are both readable and must not look alike")
        }
    }

    /// Within one category the rows sit next to each other, so no two *adjacent*
    /// providers in the picker may share a colour: an eye comparing two
    /// neighbouring rows is exactly the comparison the colour has to survive.
    func testNoTwoAdjacentProvidersInACategoryShareAColour() {
        let byCategory = Dictionary(grouping: Providers.all, by: { $0.category })
        for (category, providers) in byCategory {
            for (a, b) in pairs(providers.map(\.id)) {
                XCTAssertNotEqual(Providers.tint(for: a), Providers.tint(for: b),
                                  "\(a) and \(b) sit together in \(category.title)")
            }
        }
    }

    func testCategoriesAllHaveDistinctColours() {
        let tints = Category.allCases.map(\.tint)
        let descriptions = tints.map { "\($0)" }
        XCTAssertEqual(Set(descriptions).count, tints.count,
                       "two categories share a colour")
    }

    private func pairs<T>(_ items: [T]) -> [(T, T)] {
        guard items.count > 1 else { return [] }
        return (0..<(items.count - 1)).map { (items[$0], items[$0 + 1]) }
    }

    // MARK: - The tile paints

    private func render(_ view: some View) -> NSBitmapImageRep? {
        let hosting = NSHostingView(rootView: view)
        hosting.layoutSubtreeIfNeeded()
        let size = hosting.fittingSize
        guard size.width > 0, size.height > 0 else { return nil }
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()
        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return nil }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        return rep
    }

    /// The average colour of everything the tile actually painted.
    private func meanColour(of rep: NSBitmapImageRep) -> (r: CGFloat, g: CGFloat, b: CGFloat, painted: Int) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        var painted = 0
        for x in stride(from: 0, to: rep.pixelsWide, by: 1) {
            for y in stride(from: 0, to: rep.pixelsHigh, by: 1) {
                guard let c = rep.colorAt(x: x, y: y), c.alphaComponent > 0.05 else { continue }
                r += c.redComponent; g += c.greenComponent; b += c.blueComponent
                painted += 1
            }
        }
        guard painted > 0 else { return (0, 0, 0, 0) }
        return (r / CGFloat(painted), g / CGFloat(painted), b / CGFloat(painted), painted)
    }

    func testTilePaintsItsProviderColour() throws {
        // A name BurnFuse knows keeps the colour that provider is known by, so
        // "OpenAI" on a tile is the indigo OpenAI has always worn.
        let tile = ProviderTile(name: "OpenAI", size: 40)
        let rep = try XCTUnwrap(render(tile))
        let mean = meanColour(of: rep)
        XCTAssertGreaterThan(mean.painted, 100, "the tile painted almost nothing")
        XCTAssertGreaterThan(mean.b, mean.g, "an indigo tile should not be greyscale")
    }

    /// A provider of the person's own making gets a tile too — same wash, same
    /// border, its own colour from its own name.
    func testATileForANameBurnFuseHasNeverHeardOf() throws {
        let tile = ProviderTile(name: "My billing script", size: 40)
        let rep = try XCTUnwrap(render(tile))
        XCTAssertGreaterThan(meanColour(of: rep).painted, 100, "the tile painted almost nothing")
    }

    /// The whole point of one colour per name: two providers must produce
    /// visibly different pixels, or the row-level cue does not exist.
    func testTwoProvidersProduceVisiblyDifferentTiles() throws {
        let openAI = try XCTUnwrap(render(ProviderTile(name: "OpenAI", size: 40)))
        let openRouter = try XCTUnwrap(render(ProviderTile(name: "OpenRouter", size: 40)))
        let mine = try XCTUnwrap(render(ProviderTile(name: "My billing script", size: 40)))

        for (a, b) in pairs([openAI, openRouter, mine]) {
            let (ma, mb) = (meanColour(of: a), meanColour(of: b))
            let difference = max(abs(ma.r - mb.r), max(abs(ma.g - mb.g), abs(ma.b - mb.b)))
            XCTAssertGreaterThan(difference, 0.05, "two tiles rendered the same colour")
        }
    }

    /// Two providers in one category are the pair most likely to be compared, so
    /// their letters and their colours both have to differ.
    func testTwoNamesInOneCategoryLookDifferent() {
        XCTAssertNotEqual(Providers.monogram(for: "OpenAI prod"), Providers.monogram(for: "OpenAI test"))
        XCTAssertNotEqual(Providers.tint(forName: "OpenAI prod"), Providers.tint(forName: "OpenAI test"))
    }

    /// A name keeps its colour, and a name that *is* a provider's own name wears
    /// that provider's colour however it is spelled.
    func testANameKeepsItsColour() {
        XCTAssertEqual(Providers.tint(forName: "My billing script"), Providers.tint(forName: "my billing script"))
        XCTAssertEqual(Providers.tint(forName: "fal.ai"), Providers.tint(for: "fal"))
        XCTAssertEqual(Providers.tint(forName: "Claude"), Providers.tint(for: "anthropic"))
        XCTAssertEqual(Providers.tint(forName: "OpenRouter"), Providers.tint(for: "openrouter"))
    }

    /// Names the app knows nothing about still spread across the palette rather
    /// than all landing on one hue.
    func testUnfamiliarNamesDoNotAllLandOnOneColour() {
        let names = ["billing script", "images worker", "scraper fleet", "hosting", "vector store"]
        let colours = Set(names.map { "\(Providers.tint(forName: $0))" })
        XCTAssertGreaterThan(colours.count, 1, "every unfamiliar name got the same colour")
    }

    // MARK: - The band arithmetic

    func testBandAddsUpItsGroupAndSaysHowManyKeys() {
        let model = AppModel(stateURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("burnfuse-identity-\(UUID().uuidString).json"), pollInterval: 0)
        let a = model.addKey(name: "Fal images", provider: "fal", cap: 3, category: .images)
        let b = model.addKey(name: "Stability", provider: "stability", cap: 5, category: .images)
        model.record(keyID: a.id, cost: 1.5)
        model.record(keyID: b.id, cost: 2.5)

        let keys = model.state.entries.filter { $0.effectiveCategory == .images }
        let band = CategoryBand(category: .images, keys: keys)
        XCTAssertEqual(band.countPhrase, "2 keys")
        XCTAssertEqual(band.cap, 8, accuracy: 0.001)
        XCTAssertEqual(band.burn, 4, accuracy: 0.001)
        XCTAssertFalse(band.tripped)
    }

    func testBandSaysOneKeyNotOneKeys() {
        let model = AppModel(stateURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("burnfuse-identity-\(UUID().uuidString).json"), pollInterval: 0)
        let key = model.addKey(name: "Fal images", provider: "fal", cap: 3, category: .images)
        let band = CategoryBand(category: .images, keys: [key])
        XCTAssertEqual(band.countPhrase, "1 key")
        XCTAssertEqual(band.burn, 0, accuracy: 0.0001)
    }
}

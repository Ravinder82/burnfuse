import XCTest
import Foundation
import AppKit
@testable import BurnFuseUI

/// The provider catalogue is what the whole "add a key" flow leans on: it names
/// providers, groups them, and decides which of them BurnFuse can read at all.
/// These tests guard the parts a person would notice being wrong — a key
/// recognised as the wrong provider, a row that promises a read where there is
/// no endpoint, a category that puts money in the wrong pile.
final class CatalogTests: XCTestCase {

    // MARK: - Recognising a pasted key

    func testRecognisesTheKeysPeopleActuallyPaste() {
        let cases: [(String, String)] = [
            ("sk-or-v1-abc123", "openrouter"),
            ("sk-ant-api03-abc123", "anthropic"),
            ("sk-ant-admin01-abc123", "anthropic"),
            ("sk-admin-abc123", "openai"),
            ("sk-proj-abc123", "openai"),
            ("gsk_abc123", "groq"),
            ("r8_abc123", "replicate"),
            ("hf_abc123", "huggingface"),
            ("pplx-abc123", "perplexity"),
            ("xai-abc123", "xai"),
            ("fw_abc123", "fireworks"),
            ("fc-abc123", "firecrawl"),
            ("apify_api_abc123", "apify"),
            ("AKIAIOSFODNN7EXAMPLE", "aws"),
            ("sbp_abc123", "supabase"),
            ("tvly-dev-abc123", "tavily"),
            ("bb_live_abc123", "browserbase"),
            ("AIzaSyABC123", "google"),
        ]
        for (key, expected) in cases {
            XCTAssertEqual(Providers.detect(key)?.id, expected, "for \(key)")
        }
    }

    func testIgnoreTheJunkThatRidesAlongWithAPaste() {
        // The same normalising the key store does: a pasted header, a quoted
        // value, and a trailing newline must not stop the app knowing the key.
        XCTAssertEqual(Providers.detect("  Bearer sk-or-v1-abc123\n")?.id, "openrouter")
        XCTAssertEqual(Providers.detect("\"sk-ant-api03-abc123\"")?.id, "anthropic")
    }

    func testDoesNotGuessAtAKeyItCannotPlace() {
        XCTAssertNil(Providers.detect(""))
        XCTAssertNil(Providers.detect("hello"))
        XCTAssertNil(Providers.detect("sk-abcdef123456"), "a bare sk- is several providers, so it is no guess at all")
    }

    // MARK: - The catalogue itself

    func testEveryProviderSaysHowItsSpendIsRead() {
        for provider in Providers.all {
            XCTAssertFalse(provider.readHint.isEmpty, "\(provider.id) has no read hint")
            XCTAssertFalse(provider.keyLabel.isEmpty, "\(provider.id) has no key label")
            if provider.canReadLive {
                // "Reads …" is reserved for providers BurnFuse actually reads.
                XCTAssertTrue(provider.readHint.hasPrefix("Reads"),
                              "\(provider.id) can be read live but does not say so: \(provider.readHint)")
                if provider.id != "custom" {
                    XCTAssertNotNil(provider.whereToGet, "\(provider.id) must say where its key comes from")
                }
            } else {
                XCTAssertFalse(provider.readHint.hasPrefix("Reads"),
                               "\(provider.id) cannot be read live but says it reads: \(provider.readHint)")
                XCTAssertNotNil(provider.whereToRead,
                                "\(provider.id) takes a typed number and must say where to read it")
            }
        }
    }

    func testEveryProviderIsInACategoryAndThePickerCanShowIt() {
        for provider in Providers.all {
            XCTAssertTrue(Category.allCases.contains(provider.category), "\(provider.id)")
        }
        // Every category the picker offers has something in it, and the list
        // covers every provider exactly once.
        let grouped = Providers.categories.flatMap { Providers.providers(in: $0) }
        XCTAssertEqual(grouped.count, Providers.all.count)
        XCTAssertEqual(Set(grouped.map(\.id)), Set(Providers.all.map(\.id)))
    }

    func testUnknownProviderIDsFallIntoSomethingElse() {
        let provider = Providers.provider(for: "who-knows")
        XCTAssertEqual(provider.category, .other)
        XCTAssertFalse(provider.canReadLive)
        XCTAssertEqual(Providers.category(for: "who-knows"), .other)
    }

    /// A wrong symbol renders as an empty space, which is the kind of thing that
    /// ships unnoticed.
    func testEverySymbolNamesARealSFSymbol() throws {
        guard NSImage(systemSymbolName: "gear", accessibilityDescription: nil) != nil else {
            throw XCTSkip("SF Symbols are not available in this environment")
        }
        for provider in Providers.all {
            XCTAssertNotNil(NSImage(systemSymbolName: provider.symbol, accessibilityDescription: nil),
                            "\(provider.id) uses a symbol that does not exist: \(provider.symbol)")
        }
        for category in Category.allCases {
            XCTAssertNotNil(NSImage(systemSymbolName: category.symbol, accessibilityDescription: nil),
                            "category \(category.rawValue) uses a symbol that does not exist: \(category.symbol)")
        }
    }

    // MARK: - Categories on a key

    func testAKeyWithoutACategoryTakesItsProviders() {
        let openAI = BurnKey(id: "a", name: "a", provider: "openai")
        XCTAssertEqual(openAI.effectiveCategory, .coding)

        // An explicit category wins — a person who says their Replicate key is
        // for images means it.
        var replicate = BurnKey(id: "b", name: "b", provider: "replicate")
        replicate.category = .images
        XCTAssertEqual(replicate.effectiveCategory, .images)
    }

    func testSpendIsAddedUpByCategoryBiggestFirst() {
        let state = AppState(entries: [
            BurnKey(id: "a", name: "OpenAI", provider: "openai", hourlyLimit: 5, lastReading: 1.20),
            BurnKey(id: "b", name: "Claude", provider: "anthropic", hourlyLimit: 5, lastReading: 0.30),
            BurnKey(id: "c", name: "Fal images", provider: "fal", category: .images,
                    hourlyLimit: 3, lastReading: 2.10),
        ])

        let rows = state.burnByCategory
        XCTAssertEqual(rows.map(\.category), [.images, .coding])
        XCTAssertEqual(rows[0].burn, 2.10, accuracy: 0.0001)
        XCTAssertEqual(rows[1].burn, 1.50, accuracy: 0.0001, "both coding keys, added together")
        XCTAssertEqual(rows[1].cap, 10, accuracy: 0.0001)
    }

    func testACategoryHoldingATrippedKeySaysSo() {
        let state = AppState(entries: [
            BurnKey(id: "a", name: "OpenAI", provider: "openai", status: "tripped", lastReading: 9.9),
        ])
        XCTAssertEqual(state.burnByCategory.first?.tripped, true)
    }

    // MARK: - State that outlives the schema

    /// A key file written before categories existed still loads, and its keys
    /// fall back to whatever their provider says they are.
    func testAnOlderKeyStillLoadsAndIsCategorised() throws {
        let json = """
        {"entries":[{"id":"a","name":"OpenAI prod","provider":"openai","hourlyLimit":5,"readings":[],"lastReading":1.2}]}
        """
        let state = try JSONDecoder().decode(AppState.self, from: Data(json.utf8))
        let key = try XCTUnwrap(state.entries.first)
        XCTAssertNil(key.category)
        XCTAssertNil(key.readMode)
        XCTAssertEqual(key.effectiveCategory, .coding)
        XCTAssertFalse(key.isManualRead)
    }

    func testAManualKeyAndItsCategorySurviveARoundTrip() throws {
        let key = BurnKey(id: "a", name: "Fal images", provider: "fal", category: .images,
                          readMode: .manual, hourlyLimit: 3)
        let data = try JSONEncoder().encode(key)
        let back = try JSONDecoder().decode(BurnKey.self, from: data)
        XCTAssertEqual(back.category, .images)
        XCTAssertEqual(back.readMode, .manual)
        XCTAssertTrue(back.isManualRead)
        XCTAssertEqual(back.effectiveCategory, .images)
    }

    func testTheModelMovesAKeyBetweenReadingAndTyping() throws {
        Credentials.set(nil, for: "openai")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("burnfuse-manual-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        MainActor.assumeIsolated {
            let model = AppModel(stateURL: url, pollInterval: 0)
            let key = model.addKey(name: "OpenAI prod", provider: "openai", cap: 5,
                                   category: .coding, readMode: .manual)

            let reloaded = AppModel.read(from: url)
            XCTAssertEqual(reloaded.entries.first?.readMode, .manual)

            model.setReadMode(keyID: key.id, mode: .auto)
            XCTAssertNil(AppModel.read(from: url).entries.first?.readMode,
                         "auto is the absence of the override, not a second value to keep in step")

            model.setCategory(keyID: key.id, category: .images)
            XCTAssertEqual(AppModel.read(from: url).entries.first?.category, .images)
        }
    }
}

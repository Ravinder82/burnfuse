import XCTest
import Foundation
@testable import BurnFuseUI

/// The add-a-provider flow, and the rules behind it.
///
/// Settings has no catalogue to pick from any more: you name a provider, paste
/// what you have, and the app works out the rest. These tests guard the working
/// out — the order the guesses are used in, what the form promises while it is
/// being filled in, what a provider ends up called, and which key a row actually
/// reads with.
final class ProviderPlanTests: XCTestCase {

    // MARK: - Recognising a name

    func testRecognisesTheProviderNamesPeopleType() {
        let cases: [(String, String?)] = [
            ("OpenAI", "openai"),
            ("openai", "openai"),
            ("My OpenAI key", "openai"),
            ("OpenAI prod", "openai"),
            ("Prod GPT", "openai"),
            ("Claude", "anthropic"),
            ("Claude batch", "anthropic"),
            ("Google Gemini", "google"),
            ("gemini flash", "google"),
            ("Grok", "xai"),
            ("fal", "fal"),
            ("fal.ai", "fal"),
            ("Fal images", "fal"),
            ("Hugging Face", "huggingface"),
            ("hf", "huggingface"),
            ("Google Cloud", "gcp"),
            ("open router", "openrouter"),
            ("together_ai", "together"),
            // Names BurnFuse has never heard of name nobody.
            ("My billing script", nil),
            ("images worker", nil),
            ("vector store", nil),
            ("", nil),
            // Words shorter than three letters are never taken for a provider's
            // name on their own — "ai" is not a provider.
            ("ai", nil),
            ("hf", "huggingface"),
            ("q", nil),
        ]
        for (name, expected) in cases {
            XCTAssertEqual(Providers.match(name: name)?.id, expected, "for \"\(name)\"")
        }
    }

    func testMonogramIsTheNamesOwnLetters() {
        XCTAssertEqual(Providers.monogram(for: "OpenAI"), "O")
        XCTAssertEqual(Providers.monogram(for: "OpenAI prod"), "OP")
        XCTAssertEqual(Providers.monogram(for: "my billing script"), "MB")
        XCTAssertEqual(Providers.monogram(for: "OpenAI 2"), "O2")
        XCTAssertEqual(Providers.monogram(for: "   "), "?")
    }

    // MARK: - What adding will do

    func testAnAdminKeyIsReadForYouAndFiledBeforeAnyoneHasToSaySo() {
        let plan = Providers.plan(name: "", key: "sk-admin-01J8ZQ4K7F2M9T3B6N5R8V1X4C7D0G3H6")
        XCTAssertEqual(plan.kind, "openai")
        XCTAssertEqual(plan.name, "OpenAI")
        XCTAssertEqual(plan.category, .coding)
        XCTAssertEqual(plan.readMode, .auto)
        XCTAssertFalse(plan.wantsAddress)
        XCTAssertTrue(plan.note.contains("OpenAI"), plan.note)
    }

    func testTheNameYouGaveItIsWhatItIsCalled() {
        let plan = Providers.plan(name: "Prod GPT", key: "sk-admin-abc123456")
        XCTAssertEqual(plan.name, "Prod GPT")
        XCTAssertEqual(plan.kind, "openai", "the key's shape decides which reader it belongs to")
        XCTAssertEqual(plan.category, .coding)
    }

    /// A name BurnFuse knows files the provider, even when nothing about the key
    /// says anything — which is the whole point of naming it.
    func testANameIsEnoughToFileAndExplainAProvider() {
        let plan = Providers.plan(name: "Fal images", key: "")
        XCTAssertEqual(plan.kind, "fal")
        XCTAssertEqual(plan.category, .images)
        XCTAssertEqual(plan.readMode, .manual, "fal publishes no number to read")
        XCTAssertTrue(plan.wantsAddress, "an address of your own is the one way to make it read itself")
        XCTAssertTrue(plan.note.contains("fal"), plan.note)
    }

    func testAProviderOfYourOwnWithNothingToReadIsTyped() {
        let plan = Providers.plan(name: "My billing script", key: "totally-unknown-key-shape")
        XCTAssertEqual(plan.kind, "custom")
        XCTAssertEqual(plan.name, "My billing script")
        XCTAssertEqual(plan.category, .other)
        XCTAssertEqual(plan.readMode, .manual)
        XCTAssertTrue(plan.wantsAddress, "the form offers the address, since nothing else can read it")
        XCTAssertTrue(plan.note.contains("address"), plan.note)
    }

    func testAnAddressIsReadAndWinsOverWhatAKeyLooksLike() {
        let plan = Providers.plan(
            name: "Our own meter",
            key: "sk-admin-abc123456",
            spendUrl: "https://billing.example.com/cost.json",
            jsonPath: "data.total",
            measures: "total"
        )
        XCTAssertEqual(plan.kind, "custom")
        XCTAssertEqual(plan.readMode, .auto)
        XCTAssertEqual(plan.spendUrl, "https://billing.example.com/cost.json")
        XCTAssertEqual(plan.jsonPath, "data.total")
        XCTAssertEqual(plan.measures, "total")
        XCTAssertFalse(plan.wantsAddress)
        XCTAssertTrue(plan.note.contains("address"), plan.note)
    }

    func testAnAddressNamesAProviderNobodyNamed() {
        let plan = Providers.plan(name: "", key: "", spendUrl: "https://billing.example.com/cost.json")
        XCTAssertEqual(plan.name, "billing.example.com")
        XCTAssertEqual(plan.readMode, .auto)
    }

    func testNoAddressAndNoKeyIsStillAProviderYouCanAdd() {
        let plan = Providers.plan(name: "Scraper fleet", key: "")
        XCTAssertEqual(plan.kind, "custom")
        XCTAssertEqual(plan.readMode, .manual)
        XCTAssertEqual(plan.category, .other)
    }

    /// Two providers cannot share a name: "OpenRouter" and then "OpenRouter 2".
    func testASecondProviderOfOneNameIsNumbered() {
        let first = Providers.plan(name: "", key: "sk-or-v1-abc123",
                                   existingNames: ["OpenRouter"])
        XCTAssertEqual(first.name, "OpenRouter 2")

        let third = Providers.plan(name: "OpenRouter", key: "sk-or-v1-abc123",
                                   existingNames: ["OpenRouter", "OpenRouter 2"])
        XCTAssertEqual(third.name, "OpenRouter 3")
    }

    /// A key that needs an Admin key to read with, with no key pasted, is typed
    /// until one arrives — and the note says what would change that.
    func testAReadableProviderWithNoKeyYetIsTyped() {
        let plan = Providers.plan(name: "OpenAI", key: "")
        XCTAssertEqual(plan.kind, "openai")
        XCTAssertEqual(plan.readMode, .manual)
        XCTAssertTrue(plan.note.contains("paste"), plan.note)
    }

    func testChoosingACategoryFilesItWhereYouSaid() {
        let plan = Providers.plan(name: "Prod GPT", key: "sk-admin-abc123456",
                                  category: .images)
        XCTAssertEqual(plan.category, .images, "a person who files it themselves means it")
    }

    // MARK: - What a row says

    /// The one distinction that matters on a row: is the figure read, or typed?
    /// A provider of your own with no address can never be read, and saying
    /// "reads itself" there would be the app describing a thing it cannot do.
    func testARowSaysHowItsNumberArrives() {
        let live = BurnKey(id: "a", name: "OpenRouter", provider: "openrouter")
        XCTAssertEqual(live.readingSourcePhrase, "reads itself")

        let typed = BurnKey(id: "b", name: "My billing script", provider: "custom", readMode: .manual)
        XCTAssertEqual(typed.readingSourcePhrase, "you type it")

        let noAddress = BurnKey(id: "c", name: "No address", provider: "custom")
        XCTAssertEqual(noAddress.readingSourcePhrase, "you type it",
                       "a custom provider with no address reads nothing")

        let withAddress = BurnKey(id: "d", name: "Our meter", provider: "custom",
                                  source: KeySource(spendUrl: "https://example.com/cost.json"))
        XCTAssertEqual(withAddress.readingSourcePhrase, "reads itself")
    }

    /// The name is the row's identity, so the provider's own name is only said
    /// again where it adds something.
    func testTheKindIsOnlyNamedWhenItAddsSomething() {
        let named = BurnKey(id: "a", name: "OpenAI", provider: "openai")
        XCTAssertFalse(named.showsKindLabel)
        XCTAssertEqual(named.subtitlePhrase, "Coding & chat · reads itself")

        let renamed = BurnKey(id: "b", name: "Prod GPT", provider: "openai")
        XCTAssertTrue(renamed.showsKindLabel)
        XCTAssertEqual(renamed.subtitlePhrase, "Coding & chat · OpenAI · reads itself")

        let mine = BurnKey(id: "c", name: "Prod GPT", provider: "custom")
        XCTAssertFalse(mine.showsKindLabel, "there is no provider to name beyond the one you made")
        XCTAssertEqual(mine.readerPhrase, "you type it")

        let mine2 = BurnKey(id: "d", name: "Prod GPT", provider: "custom",
                            source: KeySource(spendUrl: "https://example.com/cost.json"))
        XCTAssertEqual(mine2.readerPhrase, "reads itself")
    }

    // MARK: - The key belongs to the provider you made

    private func withTempKeys(_ body: () -> Void) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("burnfuse-plan-keys-\(UUID().uuidString).json")
        setenv("BURNFUSE_KEYS", url.path, 1)
        unsetenv("OPENROUTER_API_KEY")
        unsetenv("OPENAI_ADMIN_KEY")
        defer {
            unsetenv("BURNFUSE_KEYS")
            try? FileManager.default.removeItem(at: url)
        }
        body()
    }

    func testAnEntryWithNoKeyOfItsOwnFallsBackToTheOneSavedForTheProvider() {
        withTempKeys {
            // A key saved before entries existed — or by a script — is still the
            // key this entry reads with.
            Credentials.set("sk-or-saved-earlier", for: "openrouter")
            let entry = BurnKey(id: "entry-1", name: "OpenRouter", provider: "openrouter")
            XCTAssertEqual(Credentials.key(for: entry), "sk-or-saved-earlier")
            XCTAssertEqual(Credentials.source(for: entry), .stored)
        }
    }

    func testAnEntryWithItsOwnKeyIgnoresTheProviders() {
        withTempKeys {
            Credentials.set("sk-or-the-other-one", for: "openrouter")
            let mine = BurnKey(id: "entry-1", name: "OpenRouter prod", provider: "openrouter")
            Credentials.set("sk-or-mine", for: mine.id)

            XCTAssertEqual(Credentials.key(for: mine), "sk-or-mine")
            XCTAssertEqual(Credentials.masked(for: mine), "sk-o…mine")

            // …and the other entry of the same provider keeps reading with the
            // provider's key rather than borrowing this one's.
            let theirs = BurnKey(id: "entry-2", name: "OpenRouter test", provider: "openrouter")
            XCTAssertEqual(Credentials.key(for: theirs), "sk-or-the-other-one")
        }
    }

    func testClearingAnEntrysKeyGoesBackToTheFallback() {
        withTempKeys {
            Credentials.set("sk-or-saved-earlier", for: "openrouter")
            let mine = BurnKey(id: "entry-1", name: "OpenRouter prod", provider: "openrouter")
            Credentials.set("sk-or-mine", for: mine.id)
            XCTAssertEqual(Credentials.key(for: mine), "sk-or-mine")

            Credentials.set(nil, for: mine.id)
            XCTAssertEqual(Credentials.key(for: mine), "sk-or-saved-earlier")
        }
    }

    func testAPlaceholderOnAnEntryIsNeverSent() {
        withTempKeys {
            let entry = BurnKey(id: "entry-1", name: "OpenRouter", provider: "openrouter")
            Credentials.set("your_openrouter_api_key_here", for: entry.id)
            XCTAssertNil(Credentials.key(for: entry))
            XCTAssertEqual(Credentials.source(for: entry), .storedPlaceholder)
        }
    }

    /// Removing a provider takes its secret with it: nothing left behind should
    /// sit on disk serving nobody.
    func testRemovingAProviderClearsItsKey() {
        let stateURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("burnfuse-plan-state-\(UUID().uuidString).json")
        let keysURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("burnfuse-plan-keys-\(UUID().uuidString).json")
        setenv("BURNFUSE_KEYS", keysURL.path, 1)
        defer {
            unsetenv("BURNFUSE_KEYS")
            try? FileManager.default.removeItem(at: stateURL)
            try? FileManager.default.removeItem(at: keysURL)
        }

        MainActor.assumeIsolated {
            let model = AppModel(stateURL: stateURL, pollInterval: 0)
            let entry = model.addKey(name: "Our meter", provider: "custom", cap: 5,
                                     readMode: .manual, spendUrl: "https://example.com/cost.json")
            model.storeCredential("some-token", forKeyID: entry.id)
            XCTAssertEqual(Credentials.key(for: entry), "some-token")

            model.remove(keyID: entry.id)
            XCTAssertNil(Credentials.key(for: entry), "the key went with the provider")
        }
    }
}

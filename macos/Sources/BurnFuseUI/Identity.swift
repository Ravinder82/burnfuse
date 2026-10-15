import SwiftUI

/// Identity: the tile and the colour that answer "which of these is which"
/// before you read a word.
///
/// The problem this is for: a settings list where every row looks the same, so
/// finding the fal key among five rows of grey text takes reading and comparing
/// instead of a glance. Two things fix that without adding a control anyone has
/// to learn:
///
///   1. **A tile per provider.** Every row about a provider leads with the same
///      small square — that provider's own symbol, in that provider's colour.
///      Two keys from one provider look identical; two providers never do.
///   2. **A band per category.** Rows are grouped under the thing the keys are
///      *for*, so "images, video, coding" is the shape of the screen and each
///      key sits where the person who added it would look for it.
///
/// Colour is never the only thing saying something: the provider's name is
/// written beside the tile and the category's name is written on the band. All
/// of these are system colours, so light, dark, Increased Contrast and colour
/// filters all keep working.
public extension Providers {

    /// The colour a provider is known by — the same one on its tile in Settings
    /// and on its row in the watch list, so the two screens agree.
    ///
    /// Curated first: providers that can appear next to each other are given
    /// visibly different colours. Anything BurnFuse has not heard of falls
    /// through to a hash of its id, which is stable forever after — a provider
    /// whose colour changed between launches would be worse than no colour.
    static func tint(for id: String) -> Color {
        if let curated = curatedTints[id] { return curated }
        let palette = fallbackPalette
        guard !id.isEmpty else { return palette[palette.count - 1] }
        var hash: UInt64 = 5381
        for byte in id.utf8 { hash = (hash &* 33) &+ UInt64(byte) }
        return palette[Int(hash % UInt64(palette.count))]
    }

    static func tint(for provider: Provider) -> Color { tint(for: provider.id) }

    /// A colour from the palette, by name, for the places that need to name one
    /// (the curated map below, and tests that check two providers differ).
    private static var fallbackPalette: [Color] { ProviderPalette.all }

    /// No two providers inside one category share a colour, and the providers
    /// people actually have (the live ones, the big ones) are kept apart even
    /// across categories.
    private static var curatedTints: [String: Color] {
        [
            // Coding & chat
            "openai": ProviderPalette.indigo,
            "anthropic": ProviderPalette.cyan,
            "google": ProviderPalette.pink,
            "xai": ProviderPalette.gray,
            "mistral": ProviderPalette.blue,
            "deepseek": ProviderPalette.purple,
            "groq": ProviderPalette.brown,
            "together": ProviderPalette.teal,
            "fireworks": ProviderPalette.indigo,
            "perplexity": ProviderPalette.purple,

            // Model aggregators
            "openrouter": ProviderPalette.blue,
            "replicate": ProviderPalette.brown,
            "huggingface": ProviderPalette.cyan,

            // Images
            "stability": ProviderPalette.pink,
            "fal": ProviderPalette.blue,

            // Video
            "runway": ProviderPalette.purple,
            "luma": ProviderPalette.teal,

            // Voice & audio
            "elevenlabs": ProviderPalette.brown,
            "deepgram": ProviderPalette.pink,

            // Scraping & search
            "firecrawl": ProviderPalette.teal,
            "apify": ProviderPalette.purple,
            "browserbase": ProviderPalette.blue,
            "exa": ProviderPalette.indigo,
            "tavily": ProviderPalette.brown,

            // Hosting & storage
            "aws": ProviderPalette.gray,
            "gcp": ProviderPalette.blue,
            "azure": ProviderPalette.cyan,
            "cloudflare": ProviderPalette.brown,
            "vercel": ProviderPalette.indigo,
            "supabase": ProviderPalette.teal,

            // Something else
            "custom": ProviderPalette.indigo,
        ]
    }
}

/// The eight hues a provider can wear. All of them are system colours — so
/// light, dark, Increased Contrast and colour filters are handled by the system
/// — and none of them is green, amber or red, which in this app mean settled,
/// climbing and tripped.
enum ProviderPalette {
    static let blue = Color(nsColor: .systemBlue)
    static let indigo = Color(nsColor: .systemIndigo)
    static let pink = Color(nsColor: .systemPink)
    static let purple = Color(nsColor: .systemPurple)
    static let teal = Color(nsColor: .systemTeal)
    static let cyan = Color(nsColor: .systemCyan)
    static let brown = Color(nsColor: .systemBrown)
    static let gray = Color(nsColor: .systemGray)

    static let all: [Color] = [blue, indigo, pink, purple, teal, cyan, brown, gray]
}

/// A provider's tile: the small square that leads every row about it. The mark
/// is the provider's own symbol, on a wash of its own colour.
public struct ProviderTile: View {
    let provider: Provider
    var size: CGFloat = 26

    public init(provider: Provider, size: CGFloat = 26) {
        self.provider = provider
        self.size = size
    }

    private var tint: Color { Providers.tint(for: provider) }

    public var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(tint.opacity(0.16))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .strokeBorder(tint.opacity(0.30), lineWidth: 1)
            )
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: provider.symbol)
                    .font(.system(size: size * 0.46, weight: .medium))
                    .foregroundStyle(tint)
            )
            // The provider's name is always written beside the tile, so the tile
            // itself has nothing to announce.
            .accessibilityHidden(true)
    }
}

/// The band that heads a group of keys in one category: what they are for, how
/// many there are, and what the group is burning against its caps.
public struct CategoryBand: View {
    let category: Category
    let keys: [BurnKey]
    /// Shown instead of the live figures when this group is the one being
    /// edited in the add flow and has nothing in it yet.
    var showsFigures: Bool = true

    public init(category: Category, keys: [BurnKey], showsFigures: Bool = true) {
        self.category = category
        self.keys = keys
        self.showsFigures = showsFigures
    }

    var burn: Double { keys.reduce(0) { $0 + $1.lastReading } }
    var cap: Double { keys.reduce(0) { $0 + $1.hourlyLimit } }
    var tripped: Bool { keys.contains { $0.isTripped } }

    var countPhrase: String {
        keys.count == 1 ? "1 key" : "\(keys.count) keys"
    }

    public var body: some View {
        HStack(spacing: DS.Space.sm) {
            Image(systemName: category.symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(category.tint)
                .frame(width: 16)

            Text(category.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(category.tint)

            Text("· \(countPhrase)")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer(minLength: DS.Space.sm)

            if showsFigures, !keys.isEmpty {
                Text("\(Fmt.perHour(burn)) of \(Fmt.money(cap)) cap")
                    .font(DS.Font.monoSmall)
                    .foregroundStyle(tripped ? AnyShapeStyle(DS.Tone.breach) : AnyShapeStyle(.secondary))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category.title), \(countPhrase)")
    }
}

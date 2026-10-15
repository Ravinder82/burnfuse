import Foundation

/// Display metadata for providers. Names, symbols, and what each one's key is
/// for, kept in one place so every screen agrees — and so a new provider is a
/// one-line addition rather than a hand-written block in three views.
public struct Provider: Identifiable, Hashable, Sendable {
    public let id: String
    public let label: String
    public let supportsLiveSpend: Bool
    public let symbol: String
    /// What the app calls this provider's credential in the UI.
    public let keyLabel: String
    /// One line on what the key does, and what to do instead when this provider
    /// has no public spend read. Never a silent dead end.
    public let keyHint: String
    /// Where in the provider's own console this key comes from, in plain words.
    /// Nobody knows where an "admin key" lives the first time; saying so here is
    /// the difference between adding a key and giving up.
    public let whereToGet: String?

    public init(
        id: String,
        label: String,
        supportsLiveSpend: Bool,
        symbol: String,
        keyLabel: String,
        keyHint: String,
        whereToGet: String? = nil
    ) {
        self.id = id
        self.label = label
        self.supportsLiveSpend = supportsLiveSpend
        self.symbol = symbol
        self.keyLabel = keyLabel
        self.keyHint = keyHint
        self.whereToGet = whereToGet
    }
}

public enum Providers {

    /// Providers that can be read live come first, so the picker and the
    /// settings list both lead with the providers that need nothing from you
    /// but a key.
    public static let all: [Provider] = [
        Provider(
            id: "openai",
            label: "OpenAI",
            supportsLiveSpend: true,
            symbol: "sparkles",
            keyLabel: "OpenAI admin key",
            keyHint: "Reads your organization's costs. Stored on this Mac only.",
            whereToGet: "OpenAI dashboard → Settings → Organization → Admin keys"
        ),
        Provider(
            id: "anthropic",
            label: "Anthropic",
            supportsLiveSpend: true,
            symbol: "text.book.closed",
            keyLabel: "Anthropic admin key",
            keyHint: "Reads your organization's costs. Needs an Admin key on an organization account — individual accounts have no Admin API.",
            whereToGet: "Claude Console → Settings → Admin keys"
        ),
        Provider(
            id: "openrouter",
            label: "OpenRouter",
            supportsLiveSpend: true,
            symbol: "arrow.triangle.branch",
            keyLabel: "OpenRouter key",
            keyHint: "Reads your credit usage. Stored on this Mac only.",
            whereToGet: "OpenRouter → Settings → Keys"
        ),
        Provider(
            id: "custom",
            label: "Custom endpoint",
            supportsLiveSpend: true,
            symbol: "point.3.connected.trianglepath.dotted",
            keyLabel: "Custom endpoint key",
            keyHint: "Optional. Sent with your own cost endpoint when it asks for one."
        ),
        Provider(
            id: "replicate",
            label: "Replicate",
            supportsLiveSpend: false,
            symbol: "square.stack.3d.up",
            keyLabel: "Replicate token",
            keyHint: "No public spend read. Log a reading, or point a custom endpoint at one."
        ),
        Provider(
            id: "groq",
            label: "Groq",
            supportsLiveSpend: false,
            symbol: "bolt.fill",
            keyLabel: "Groq key",
            keyHint: "No public spend read. Log a reading, or point a custom endpoint at one."
        ),
        Provider(
            id: "aws",
            label: "AWS",
            supportsLiveSpend: false,
            symbol: "cloud",
            keyLabel: "AWS access key",
            keyHint: "No single cost read. Cost Explorer can export one — point a custom endpoint at it, or log a reading."
        ),
    ]

    public static func label(for id: String) -> String {
        // Delegating keeps this and `provider(for:)` describing an unknown id
        // the same way — a key labelled two different things is a bug report.
        provider(for: id).label
    }

    public static func provider(for id: String) -> Provider {
        if let match = all.first(where: { $0.id == id }) { return match }
        // An id we do not recognise — say so as itself rather than pretending it
        // is a custom endpoint and pointing the user at a form that will not
        // help them.
        return Provider(
            id: id,
            label: id.capitalized,
            supportsLiveSpend: false,
            symbol: "questionmark.circle",
            keyLabel: "\(id.capitalized) key",
            keyHint: "Stored on this Mac only."
        )
    }
}

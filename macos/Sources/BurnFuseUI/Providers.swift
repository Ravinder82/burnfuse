import Foundation

/// Display metadata for providers. The CLI owns the network behaviour; the
/// app mirrors the names so the two never disagree about what you are looking at.
public struct Provider: Identifiable, Hashable, Sendable {
    public let id: String
    public let label: String
    public let supportsLiveSpend: Bool
    public let symbol: String

    public init(id: String, label: String, supportsLiveSpend: Bool, symbol: String) {
        self.id = id
        self.label = label
        self.supportsLiveSpend = supportsLiveSpend
        self.symbol = symbol
    }
}

public enum Providers {
    public static let all: [Provider] = [
        Provider(id: "openai", label: "OpenAI", supportsLiveSpend: true, symbol: "sparkles"),
        Provider(id: "anthropic", label: "Anthropic", supportsLiveSpend: false, symbol: "text.book.closed"),
        Provider(id: "openrouter", label: "OpenRouter", supportsLiveSpend: true, symbol: "arrow.triangle.branch"),
        Provider(id: "replicate", label: "Replicate", supportsLiveSpend: false, symbol: "square.stack.3d.up"),
        Provider(id: "groq", label: "Groq", supportsLiveSpend: false, symbol: "bolt.fill"),
        Provider(id: "aws", label: "AWS", supportsLiveSpend: false, symbol: "cloud"),
        Provider(id: "custom", label: "Custom endpoint", supportsLiveSpend: true, symbol: "point.3.connected.trianglepath.dotted"),
    ]

    public static func label(for id: String) -> String {
        all.first { $0.id == id }?.label ?? "Custom endpoint"
    }

    public static func provider(for id: String) -> Provider {
        all.first { $0.id == id } ?? all.last!
    }
}
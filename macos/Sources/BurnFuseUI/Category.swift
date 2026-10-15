import Foundation

/// What a key is *for*. This is how you think about your spend, and nothing
/// else: the same grouping on Overview ("Images $0.40/hr") and the same
/// headings in the picker when you add a key.
///
/// A category never decides whether BurnFuse can read a key. That is a fact
/// about the provider, and the provider says it in one line. Conflating the two
/// is how an app ends up calling an Images key "manual" for reasons that have
/// nothing to do with images.
public enum Category: String, CaseIterable, Identifiable, Sendable, Codable {
    case coding
    case images
    case video
    case audio
    case scraping
    case hosting
    case aggregator
    case other

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .coding: return "Coding & chat"
        case .images: return "Images"
        case .video: return "Video"
        case .audio: return "Voice & audio"
        case .scraping: return "Scraping & search"
        case .hosting: return "Hosting & storage"
        case .aggregator: return "Model aggregators"
        case .other: return "Something else"
        }
    }

    /// The shortest true description, for the picker.
    public var blurb: String {
        switch self {
        case .coding: return "LLM and chat APIs"
        case .images: return "Image generation and editing"
        case .video: return "Video generation"
        case .audio: return "Speech, voice and transcription"
        case .scraping: return "Crawling, browsing and search"
        case .hosting: return "Cloud, compute and storage"
        case .aggregator: return "Many models behind one bill"
        case .other: return "A key I did not list"
        }
    }

    public var symbol: String {
        switch self {
        case .coding: return "chevron.left.forwardslash.chevron.right"
        case .images: return "photo"
        case .video: return "film"
        case .audio: return "waveform"
        case .scraping: return "network"
        case .hosting: return "cloud"
        case .aggregator: return "square.stack.3d.up"
        case .other: return "ellipsis.circle"
        }
    }

    /// What a new key gets when the provider does not say. "Something else" is
    /// the honest default — it never mislabels a key in a way someone has to go
    /// and fix.
    public static let fallback: Category = .other
}

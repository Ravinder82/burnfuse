import Foundation

/// One provider BurnFuse knows about. Names, category, and what its spend read
/// can do — kept in one place so every screen agrees, and so a new provider is
/// a few lines here rather than a hand-written block in three views.
///
/// The one field worth being careful with is `canReadLive`. It is not a
/// preference and not a promise: it means the provider publishes an endpoint
/// that returns a dollar figure, and a key can call it. Where that is true,
/// BurnFuse reads the number and the user types nothing. Where it is not, the
/// row says so in `readHint` and takes a typed number instead. There is no third
/// state, and nothing is ever silently monitored.
public struct Provider: Identifiable, Hashable, Sendable {
    public let id: String
    public let label: String
    /// What this key is for. Organisation only — see `Category`.
    public let category: Category
    /// Can BurnFuse read a dollar figure for this provider without being told?
    public let canReadLive: Bool
    public let symbol: String
    /// What the app calls this provider's credential in the UI.
    public let keyLabel: String
    /// One line, always true, on what reading spend does here — including when
    /// the answer is "nothing automatic". Written to be the last thing someone
    /// needs to read before they understand the row.
    public let readHint: String
    /// Where in the provider's own console this key comes from, in plain words.
    /// Nobody knows where an "admin key" lives the first time; saying so is the
    /// difference between adding a key and giving up.
    public let whereToGet: String?
    /// Where the number itself lives, for providers whose spend has to be typed.
    /// The instruction "type what it is spending" is only useful next to where
    /// to read it.
    public let whereToRead: String?
    /// Where the same key is revoked or rotated, in plain words.
    ///
    /// This is the one action that actually stops spend, and BurnFuse cannot take
    /// it on the user's behalf: reading a cost figure and revoking a credential
    /// are different permissions, and a spend watcher holding revocation rights
    /// over your keys would be a worse thing to install than the problem it
    /// solves. So the app points, precisely, instead of gesturing.
    public let whereToRevoke: String?
    /// The start of a key, where the provider uses a recognisable one. This is
    /// what lets a pasted key be identified before anyone is asked to pick a
    /// provider from a list they may not understand.
    public let keyPrefixes: [String]

    public init(
        id: String,
        label: String,
        category: Category,
        canReadLive: Bool = false,
        symbol: String,
        keyLabel: String,
        readHint: String,
        whereToGet: String? = nil,
        whereToRead: String? = nil,
        whereToRevoke: String? = nil,
        keyPrefixes: [String] = []
    ) {
        self.id = id
        self.label = label
        self.category = category
        self.canReadLive = canReadLive
        self.symbol = symbol
        self.keyLabel = keyLabel
        self.readHint = readHint
        self.whereToGet = whereToGet
        self.whereToRead = whereToRead
        self.whereToRevoke = whereToRevoke
        self.keyPrefixes = keyPrefixes
    }
}

public enum Providers {

    /// Every provider BurnFuse can name, grouped by category in the order the
    /// picker shows them. Coding leads because that is where most AI spend is;
    /// "Something else" is last and always present, so a provider that is not
    /// listed is never a dead end.
    public static let all: [Provider] = [

        // MARK: Coding & chat

        Provider(
            id: "openai",
            label: "OpenAI",
            category: .coding,
            canReadLive: true,
            symbol: "sparkles",
            keyLabel: "OpenAI key",
            readHint: "Reads your organization's costs. Needs an Admin key — a normal key can use the API but cannot see spend.",
            whereToGet: "OpenAI dashboard → Settings → Organization → Admin keys",
            whereToRevoke: "OpenAI dashboard → API keys",
            keyPrefixes: ["sk-admin-", "sk-proj-", "sk-svcacct-", "sk-org-"]
        ),
        Provider(
            id: "anthropic",
            label: "Anthropic",
            category: .coding,
            canReadLive: true,
            symbol: "text.book.closed",
            keyLabel: "Anthropic key",
            readHint: "Reads your organization's costs. Needs an Admin key, and organization accounts only.",
            whereToGet: "Claude Console → Settings → Admin keys",
            whereToRevoke: "Claude Console → API keys",
            keyPrefixes: ["sk-ant-"]
        ),
        Provider(
            id: "google",
            label: "Google Gemini",
            category: .coding,
            symbol: "sparkle",
            keyLabel: "Google AI key",
            readHint: "No spend read. Google reports Gemini spend in Cloud Billing, not through an API key.",
            whereToRead: "Google Cloud Console → Billing",
            whereToRevoke: "Google AI Studio → API keys",
            keyPrefixes: ["AIza"]
        ),
        Provider(
            id: "xai",
            label: "xAI (Grok)",
            category: .coding,
            symbol: "x.circle",
            keyLabel: "xAI key",
            readHint: "No spend read — the xAI console is the only place the number exists.",
            whereToRead: "console.x.ai → Usage",
            whereToRevoke: "console.x.ai → API keys",
            keyPrefixes: ["xai-"]
        ),
        Provider(
            id: "mistral",
            label: "Mistral",
            category: .coding,
            symbol: "wind",
            keyLabel: "Mistral key",
            readHint: "No spend read — the Mistral console is the only place the number exists.",
            whereToRead: "Mistral Console → Usage",
            whereToRevoke: "Mistral Console → API keys"
        ),
        Provider(
            id: "deepseek",
            label: "DeepSeek",
            category: .coding,
            symbol: "water.waves",
            keyLabel: "DeepSeek key",
            readHint: "No spend read — the DeepSeek platform is the only place the number exists.",
            whereToRead: "DeepSeek platform → Usage",
            whereToRevoke: "DeepSeek platform → API keys"
        ),
        Provider(
            id: "groq",
            label: "Groq",
            category: .coding,
            symbol: "bolt.fill",
            keyLabel: "Groq key",
            readHint: "No spend read — Groq's console keeps the number to itself.",
            whereToRead: "Groq Console → Usage",
            whereToRevoke: "Groq Console → API Keys",
            keyPrefixes: ["gsk_"]
        ),
        Provider(
            id: "together",
            label: "Together AI",
            category: .coding,
            symbol: "person.2.fill",
            keyLabel: "Together key",
            readHint: "No spend read — Together's billing page is the only place the number exists.",
            whereToRead: "Together → Settings → Billing",
            whereToRevoke: "Together → Settings → API keys"
        ),
        Provider(
            id: "fireworks",
            label: "Fireworks AI",
            category: .coding,
            symbol: "fireworks",
            keyLabel: "Fireworks key",
            readHint: "No spend read — Fireworks' billing page is the only place the number exists.",
            whereToRead: "Fireworks → Billing",
            whereToRevoke: "Fireworks → API keys",
            keyPrefixes: ["fw_"]
        ),
        Provider(
            id: "perplexity",
            label: "Perplexity",
            category: .coding,
            symbol: "magnifyingglass.circle",
            keyLabel: "Perplexity key",
            readHint: "No spend read — the Perplexity dashboard is the only place the number exists.",
            whereToRead: "Perplexity → API → Usage",
            whereToRevoke: "Perplexity → API → Keys",
            keyPrefixes: ["pplx-"]
        ),

        // MARK: Model aggregators

        Provider(
            id: "openrouter",
            label: "OpenRouter",
            category: .aggregator,
            canReadLive: true,
            symbol: "arrow.triangle.branch",
            keyLabel: "OpenRouter key",
            readHint: "Reads this key's own credit usage — the key you already use works.",
            whereToGet: "OpenRouter → Settings → Keys",
            whereToRevoke: "OpenRouter → Settings → Keys",
            keyPrefixes: ["sk-or-"]
        ),
        Provider(
            id: "replicate",
            label: "Replicate",
            category: .aggregator,
            symbol: "square.stack.3d.up",
            keyLabel: "Replicate token",
            readHint: "No spend read — Replicate's billing page is the only place the number exists.",
            whereToRead: "Replicate → Account → Billing",
            whereToRevoke: "Replicate → Account → API tokens",
            keyPrefixes: ["r8_"]
        ),
        Provider(
            id: "huggingface",
            label: "Hugging Face",
            category: .aggregator,
            symbol: "face.smiling",
            keyLabel: "Hugging Face token",
            readHint: "No spend read — Hugging Face's billing page is the only place the number exists.",
            whereToRead: "Hugging Face → Settings → Billing",
            whereToRevoke: "Hugging Face → Settings → Access tokens",
            keyPrefixes: ["hf_"]
        ),

        // MARK: Images

        Provider(
            id: "stability",
            label: "Stability AI",
            category: .images,
            symbol: "wand.and.rays",
            keyLabel: "Stability key",
            readHint: "No spend read — Stability's account page is the only place the number exists.",
            whereToRead: "Stability → Account → Credits",
            whereToRevoke: "Stability → Account → API keys"
        ),
        Provider(
            id: "fal",
            label: "fal.ai",
            category: .images,
            symbol: "hare",
            keyLabel: "fal key",
            readHint: "No spend read — fal's dashboard is the only place the number exists.",
            whereToRead: "fal.ai → Dashboard → Billing",
            whereToRevoke: "fal.ai → Dashboard → API keys"
        ),

        // MARK: Video

        Provider(
            id: "runway",
            label: "Runway",
            category: .video,
            symbol: "film",
            keyLabel: "Runway key",
            readHint: "No spend read — Runway's account page is the only place the number exists.",
            whereToRead: "Runway → Account → Usage",
            whereToRevoke: "Runway → Account → API keys"
        ),
        Provider(
            id: "luma",
            label: "Luma",
            category: .video,
            symbol: "moon.stars",
            keyLabel: "Luma key",
            readHint: "No spend read — Luma's dashboard is the only place the number exists.",
            whereToRead: "Luma → Dashboard → Billing",
            whereToRevoke: "Luma → Dashboard → API keys"
        ),

        // MARK: Voice & audio

        Provider(
            id: "elevenlabs",
            label: "ElevenLabs",
            category: .audio,
            symbol: "waveform",
            keyLabel: "ElevenLabs key",
            readHint: "No dollar read — ElevenLabs reports characters used, not money.",
            whereToRead: "ElevenLabs → Subscription",
            whereToRevoke: "ElevenLabs → Profile → API keys",
            keyPrefixes: ["sk_"]
        ),
        Provider(
            id: "deepgram",
            label: "Deepgram",
            category: .audio,
            symbol: "ear",
            keyLabel: "Deepgram key",
            readHint: "No dollar read — Deepgram's console shows usage against your plan.",
            whereToRead: "Deepgram Console → Usage",
            whereToRevoke: "Deepgram Console → API keys"
        ),

        // MARK: Scraping & search

        Provider(
            id: "firecrawl",
            label: "Firecrawl",
            category: .scraping,
            symbol: "flame",
            keyLabel: "Firecrawl key",
            readHint: "No dollar read — Firecrawl reports credits, not money.",
            whereToRead: "Firecrawl → Dashboard → Usage",
            whereToRevoke: "Firecrawl → Dashboard → API keys",
            keyPrefixes: ["fc-"]
        ),
        Provider(
            id: "apify",
            label: "Apify",
            category: .scraping,
            symbol: "ant",
            keyLabel: "Apify token",
            readHint: "No dollar read — Apify's console shows usage against your plan.",
            whereToRead: "Apify Console → Billing",
            whereToRevoke: "Apify Console → Settings → Integrations",
            keyPrefixes: ["apify_api_"]
        ),
        Provider(
            id: "browserbase",
            label: "Browserbase",
            category: .scraping,
            symbol: "globe",
            keyLabel: "Browserbase key",
            readHint: "No spend read — Browserbase's dashboard is the only place the number exists.",
            whereToRead: "Browserbase → Settings → Billing",
            whereToRevoke: "Browserbase → Settings → API keys",
            keyPrefixes: ["bb_live_", "bb_test_"]
        ),
        Provider(
            id: "exa",
            label: "Exa",
            category: .scraping,
            symbol: "binoculars",
            keyLabel: "Exa key",
            readHint: "No spend read — Exa's dashboard is the only place the number exists.",
            whereToRead: "Exa → Dashboard → Usage",
            whereToRevoke: "Exa → Dashboard → API keys"
        ),
        Provider(
            id: "tavily",
            label: "Tavily",
            category: .scraping,
            symbol: "bird",
            keyLabel: "Tavily key",
            readHint: "No spend read — Tavily's dashboard is the only place the number exists.",
            whereToRead: "Tavily → Dashboard → Usage",
            whereToRevoke: "Tavily → Dashboard → API keys",
            keyPrefixes: ["tvly-"]
        ),

        // MARK: Hosting & storage

        Provider(
            id: "aws",
            label: "AWS",
            category: .hosting,
            symbol: "cloud",
            keyLabel: "AWS access key",
            readHint: "No spend read from a key. Cost Explorer can produce a figure, but it is a different service with its own permissions.",
            whereToRead: "AWS → Billing → Cost Explorer",
            whereToRevoke: "AWS → IAM → Access keys",
            keyPrefixes: ["AKIA", "ASIA"]
        ),
        Provider(
            id: "gcp",
            label: "Google Cloud",
            category: .hosting,
            symbol: "cloud.sun",
            keyLabel: "Google Cloud key",
            readHint: "No spend read from a key — Cloud Billing holds the number.",
            whereToRead: "Google Cloud Console → Billing",
            whereToRevoke: "Google Cloud Console → IAM → Service accounts"
        ),
        Provider(
            id: "azure",
            label: "Microsoft Azure",
            category: .hosting,
            symbol: "cloud.fill",
            keyLabel: "Azure key",
            readHint: "No spend read from a key — Cost Management holds the number.",
            whereToRead: "Azure → Cost Management",
            whereToRevoke: "Azure → App registrations → Certificates & secrets"
        ),
        Provider(
            id: "cloudflare",
            label: "Cloudflare",
            category: .hosting,
            symbol: "cloud.bolt",
            keyLabel: "Cloudflare token",
            readHint: "No spend read — Cloudflare's billing page is the only place the number exists.",
            whereToRead: "Cloudflare → Billing",
            whereToRevoke: "Cloudflare → My Profile → API Tokens"
        ),
        Provider(
            id: "vercel",
            label: "Vercel",
            category: .hosting,
            symbol: "triangle",
            keyLabel: "Vercel token",
            readHint: "No spend read — Vercel's billing page is the only place the number exists.",
            whereToRead: "Vercel → Settings → Billing",
            whereToRevoke: "Vercel → Settings → Tokens"
        ),
        Provider(
            id: "supabase",
            label: "Supabase",
            category: .hosting,
            symbol: "cylinder",
            keyLabel: "Supabase token",
            readHint: "No spend read — Supabase's usage page is the only place the number exists.",
            whereToRead: "Supabase → Organization → Usage",
            whereToRevoke: "Supabase → Account → Access Tokens",
            keyPrefixes: ["sbp_"]
        ),

        // MARK: Something else

        Provider(
            id: "custom",
            label: "Your own endpoint",
            category: .other,
            canReadLive: true,
            symbol: "point.3.connected.trianglepath.dotted",
            keyLabel: "endpoint key",
            readHint: "Reads any address that returns a dollar figure — your own script, a billing export, a page behind a token."
        ),
    ]

    // MARK: - Lookups

    public static func label(for id: String) -> String {
        // Delegating keeps this and `provider(for:)` describing an unknown id
        // the same way — a key labelled two different things is a bug report.
        provider(for: id).label
    }

    /// The category a key belongs to when it does not carry one of its own.
    public static func category(for id: String) -> Category {
        provider(for: id).category
    }

    public static func canReadLive(_ id: String) -> Bool {
        provider(for: id).canReadLive
    }

    /// "a" or "an", so a sentence built from a provider's name reads like
    /// English instead of like a template.
    public static func article(_ label: String) -> String {
        guard let first = label.lowercased().first else { return "a" }
        return "aeiou".contains(first) ? "an" : "a"
    }

    public static func providers(in category: Category) -> [Provider] {
        all.filter { $0.category == category }
    }

    /// Every category that has at least one provider, in picker order.
    public static var categories: [Category] {
        Category.allCases.filter { category in all.contains { $0.category == category } }
    }

    /// Identify a provider from the shape of a pasted key.
    ///
    /// The point is to never ask someone to classify a key they do not
    /// understand: paste it, and the app says what it is. Matching is on the
    /// longest prefix, and an ambiguous match returns nil rather than a guess —
    /// being wrong here would put a key in the wrong row and read the wrong
    /// endpoint.
    public static func detect(_ raw: String) -> Provider? {
        guard let key = Credentials.sanitize(raw), key.count >= 6 else { return nil }
        let haystack = key.lowercased()

        var best: (provider: Provider, length: Int)?
        var tied = false
        for provider in all {
            for prefix in provider.keyPrefixes where haystack.hasPrefix(prefix.lowercased()) {
                if let current = best {
                    if prefix.count > current.length {
                        best = (provider, prefix.count)
                        tied = false
                    } else if prefix.count == current.length, provider.id != current.provider.id {
                        tied = true
                    }
                } else {
                    best = (provider, prefix.count)
                }
            }
        }
        guard !tied else { return nil }
        return best?.provider
    }

    /// The one line that belongs with a trip: the only action that ends the
    /// spend. Said in the notification, the webhook and the banner alike, so
    /// whoever sees it first knows what to do without opening anything.
    public static func revokeHint(for id: String) -> String {
        if let whereToRevoke = provider(for: id).whereToRevoke {
            return "Revoke the key at \(whereToRevoke) to stop the spend."
        }
        return "Revoke the key where you issued it to stop the spend."
    }

    public static func provider(for id: String) -> Provider {
        if let match = all.first(where: { $0.id == id }) { return match }
        // An id we do not recognise — say so as itself rather than pretending it
        // is a custom endpoint and pointing the user at a form that will not
        // help them.
        return Provider(
            id: id,
            label: id.capitalized,
            category: .other,
            symbol: "questionmark.circle",
            keyLabel: "\(id.capitalized) key",
            readHint: "No spend read for this provider. Type what it is spending."
        )
    }
}

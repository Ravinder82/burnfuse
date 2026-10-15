import Foundation

/// One provider BurnFuse knows about. Names, category, and what its spend read
/// can do — kept in one place so every screen agrees, and so the knowledge that
/// helps when somebody names a provider (where its key comes from, where its
/// number is read, where the key is revoked) is written once.
///
/// Nothing shows this list. You create your own providers in Settings; this is
/// what the app knows when a key's shape or a typed name tells it something, and
/// it is consulted only when it can help.
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
    /// Other things people call this provider — "claude" for Anthropic, "hf" for
    /// Hugging Face. Used to recognise a provider from the *name* somebody types
    /// when the key's shape says nothing, and to give that name the colour the
    /// provider is known by. Never shown as a list.
    public let aliases: [String]

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
        keyPrefixes: [String] = [],
        aliases: [String] = []
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
        self.aliases = aliases
    }
}

public enum Providers {

    /// Every provider BurnFuse can name, grouped by category.
    ///
    /// This is what the app knows, not a list anybody reads: Settings shows only
    /// the providers you created, and this is consulted behind the scenes when a
    /// pasted key or a typed name tells BurnFuse something useful — which pile
    /// the spend belongs in, whether the number can be read at all, where the key
    /// is revoked.
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
            keyPrefixes: ["sk-admin-", "sk-proj-", "sk-svcacct-", "sk-org-"],
            aliases: ["openai", "gpt", "chatgpt", "open ai"]
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
            keyPrefixes: ["sk-ant-"],
            aliases: ["anthropic", "claude", "claude ai"],
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
            keyPrefixes: ["AIza"],
            aliases: ["google", "gemini", "google ai", "ai studio"],
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
            keyPrefixes: ["xai-"],
            aliases: ["xai", "grok"],
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
            whereToRevoke: "DeepSeek platform → API keys",
            aliases: ["deepseek", "deep seek"],
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
            keyPrefixes: ["gsk_"],
            aliases: ["groq", "groq cloud"],
        ),
        Provider(
            id: "together",
            label: "Together AI",
            category: .coding,
            symbol: "person.2.fill",
            keyLabel: "Together key",
            readHint: "No spend read — Together's billing page is the only place the number exists.",
            whereToRead: "Together → Settings → Billing",
            whereToRevoke: "Together → Settings → API keys",
            aliases: ["together", "together ai"],
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
            keyPrefixes: ["fw_"],
            aliases: ["fireworks", "fireworks ai"],
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
            keyPrefixes: ["pplx-"],
            aliases: ["perplexity"],
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
            keyPrefixes: ["sk-or-"],
            aliases: ["openrouter", "open router"],
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
            keyPrefixes: ["r8_"],
            aliases: ["replicate"],
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
            keyPrefixes: ["hf_"],
            aliases: ["huggingface", "hugging face", "hf"],
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
            whereToRevoke: "Stability → Account → API keys",
            aliases: ["stability", "stability ai"],
        ),
        Provider(
            id: "fal",
            label: "fal.ai",
            category: .images,
            symbol: "hare",
            keyLabel: "fal key",
            readHint: "No spend read — fal's dashboard is the only place the number exists.",
            whereToRead: "fal.ai → Dashboard → Billing",
            whereToRevoke: "fal.ai → Dashboard → API keys",
            aliases: ["fal", "fal ai"],
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
            whereToRevoke: "Runway → Account → API keys",
            aliases: ["runway", "runway ml"],
        ),
        Provider(
            id: "luma",
            label: "Luma",
            category: .video,
            symbol: "moon.stars",
            keyLabel: "Luma key",
            readHint: "No spend read — Luma's dashboard is the only place the number exists.",
            whereToRead: "Luma → Dashboard → Billing",
            whereToRevoke: "Luma → Dashboard → API keys",
            aliases: ["luma", "luma ai"],
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
            keyPrefixes: ["sk_"],
            aliases: ["elevenlabs", "eleven labs"],
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
            keyPrefixes: ["fc-"],
            aliases: ["firecrawl", "fire crawl"],
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
            keyPrefixes: ["apify_api_"],
            aliases: ["apify"],
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
            keyPrefixes: ["bb_live_", "bb_test_"],
            aliases: ["browserbase"],
        ),
        Provider(
            id: "exa",
            label: "Exa",
            category: .scraping,
            symbol: "binoculars",
            keyLabel: "Exa key",
            readHint: "No spend read — Exa's dashboard is the only place the number exists.",
            whereToRead: "Exa → Dashboard → Usage",
            whereToRevoke: "Exa → Dashboard → API keys",
            aliases: ["exa"],
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
            keyPrefixes: ["tvly-"],
            aliases: ["tavily"],
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
            keyPrefixes: ["AKIA", "ASIA"],
            aliases: ["aws", "amazon web services", "amazon"],
        ),
        Provider(
            id: "gcp",
            label: "Google Cloud",
            category: .hosting,
            symbol: "cloud.sun",
            keyLabel: "Google Cloud key",
            readHint: "No spend read from a key — Cloud Billing holds the number.",
            whereToRead: "Google Cloud Console → Billing",
            whereToRevoke: "Google Cloud Console → IAM → Service accounts",
            aliases: ["gcp", "google cloud", "gcloud"],
        ),
        Provider(
            id: "azure",
            label: "Microsoft Azure",
            category: .hosting,
            symbol: "cloud.fill",
            keyLabel: "Azure key",
            readHint: "No spend read from a key — Cost Management holds the number.",
            whereToRead: "Azure → Cost Management",
            whereToRevoke: "Azure → App registrations → Certificates & secrets",
            aliases: ["azure", "microsoft azure"],
        ),
        Provider(
            id: "cloudflare",
            label: "Cloudflare",
            category: .hosting,
            symbol: "cloud.bolt",
            keyLabel: "Cloudflare token",
            readHint: "No spend read — Cloudflare's billing page is the only place the number exists.",
            whereToRead: "Cloudflare → Billing",
            whereToRevoke: "Cloudflare → My Profile → API Tokens",
            aliases: ["cloudflare"],
        ),
        Provider(
            id: "vercel",
            label: "Vercel",
            category: .hosting,
            symbol: "triangle",
            keyLabel: "Vercel token",
            readHint: "No spend read — Vercel's billing page is the only place the number exists.",
            whereToRead: "Vercel → Settings → Billing",
            whereToRevoke: "Vercel → Settings → Tokens",
            aliases: ["vercel"],
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
            keyPrefixes: ["sbp_"],
            aliases: ["supabase"],
        ),

        // MARK: Something else

        Provider(
            id: "custom",
            label: "Your own endpoint",
            category: .other,
            canReadLive: true,
            symbol: "point.3.connected.trianglepath.dotted",
            keyLabel: "endpoint key",
            readHint: "Reads any address that returns a dollar figure — your own script, a billing export, a page behind a token.",
            aliases: ["endpoint", "my endpoint", "own endpoint", "my server"],
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

    /// The provider BurnFuse knows by this id, or nothing when the id is one it
    /// has never heard of.
    public static func known(_ id: String) -> Provider? {
        all.first { $0.id == id }
    }

    /// A name, cut into lowercased words of letters and numbers: "fal.ai",
    /// "Together AI" and "together_ai" are three ways of writing the same thing,
    /// and all three have to find the same provider.
    public static func words(in text: String) -> [String] {
        text.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
    }

    /// Every name BurnFuse knows a provider by, normalised: its id, its own name,
    /// and the other things people call it.
    static let byName: [String: Provider] = {
        var index: [String: Provider] = [:]
        for provider in all {
            for name in [provider.id, provider.label] + provider.aliases {
                index[words(in: name).joined()] = provider
            }
        }
        return index
    }()

    /// What BurnFuse knows about a name somebody typed, if anything.
    ///
    /// This is the quiet half of the provider list. There is no menu to read any
    /// more — you name your own providers — but when a name means something the
    /// app can help with (where the number is read, where the key is revoked,
    /// which category it belongs in) that knowledge is used. A pasted key's own
    /// shape is the stronger signal, and callers ask `detect` first.
    ///
    /// The whole name wins, then its first word, then any word that is a
    /// provider's own name — so "OpenAI prod", "prod openai" and "My OpenAI key"
    /// all land on OpenAI. A word shorter than three letters is never used on its
    /// own, so "ai", "my" and "key" cannot stand in for a provider.
    public static func match(name: String) -> Provider? {
        let parts = words(in: name)
        guard !parts.isEmpty else { return nil }
        if let hit = byName[parts.joined()] { return hit }
        if let first = parts.first, first.count >= 3, let hit = byName[first] { return hit }
        for word in parts.dropFirst() where word.count >= 3 {
            if let hit = byName[word] { return hit }
        }
        return nil
    }

    /// The letters on a provider's tile: the initials of up to two words of the
    /// name it was given, so "OpenAI" is O and "OpenAI prod" is OP. One name, one
    /// tile, and the tile never changes for as long as the entry exists.
    public static func monogram(for name: String) -> String {
        let letters = words(in: name).prefix(2).compactMap(\.first).map { String($0).uppercased() }
        return letters.isEmpty ? "?" : letters.joined()
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

    // MARK: - What the add-a-provider form decides

    /// What adding a provider will do, worked out before anything is written.
    ///
    /// Kept out of the view so the decisions can be tested: what the provider
    /// will be called, which reader it belongs to, where it is filed, whether
    /// the number is read or typed — and the one sentence the form shows under
    /// the key field while you decide.
    public struct ProviderPlan: Equatable, Sendable {
        public var name: String
        /// The reader that knows how to fetch this provider's spend. "custom"
        /// means "an address you gave": with no address, an entry reads nothing
        /// and its numbers are typed.
        public var kind: String
        public var category: Category
        public var readMode: ReadMode
        /// The line under the key field, and the symbol beside it.
        public var note: String
        public var noteIcon: String?
        /// True when the number can only come from an address you give — the
        /// form opens its address fields for these.
        public var wantsAddress: Bool
        public var spendUrl: String?
        public var jsonPath: String?
        public var header: String?
        public var measures: String?

        public init(
            name: String,
            kind: String,
            category: Category,
            readMode: ReadMode,
            note: String,
            noteIcon: String? = nil,
            wantsAddress: Bool = false,
            spendUrl: String? = nil,
            jsonPath: String? = nil,
            header: String? = nil,
            measures: String? = nil
        ) {
            self.name = name
            self.kind = kind
            self.category = category
            self.readMode = readMode
            self.note = note
            self.noteIcon = noteIcon
            self.wantsAddress = wantsAddress
            self.spendUrl = spendUrl
            self.jsonPath = jsonPath
            self.header = header
            self.measures = measures
        }
    }

    /// Work out what the form is about to create, from what has been typed.
    ///
    /// The guesses are used in the order of their strength:
    ///
    ///   1. an address you gave — one explicit instruction, so it wins, and the
    ///      entry reads from it rather than from whatever the key looks like;
    ///   2. the shape of the key you pasted;
    ///   3. the name you gave it, when BurnFuse knows that name.
    ///
    /// With none of the three, the provider is yours alone: filed where you put
    /// it, with a number you type. A key is kept whenever one is pasted — it is
    /// yours, and it is what reads the address the moment you give one.
    public static func plan(
        name typedName: String,
        key rawKey: String,
        category chosenCategory: Category? = nil,
        spendUrl typedUrl: String = "",
        jsonPath: String = "",
        header: String = "",
        measures: String = "rate",
        existingNames: [String] = []
    ) -> ProviderPlan {
        let key = Credentials.sanitize(rawKey)
        let url = typedUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasUrl = !url.isEmpty
        let byShape = key.flatMap { detect($0) }
        let byName = match(name: typedName)
        // An address you gave is the instruction; the key's shape and the name
        // are only what could be guessed.
        let known = hasUrl ? nil : (byShape ?? byName)

        let kind = known?.id ?? "custom"
        let name = resolvedName(typed: typedName, known: known, url: url, existing: existingNames)
        let category = chosenCategory ?? known?.category ?? .other

        let canRead: Bool
        if hasUrl {
            canRead = true
        } else if let known {
            canRead = known.canReadLive && (key != nil || !SpendSource.requiresKey(kind: kind))
        } else {
            canRead = false
        }

        return ProviderPlan(
            name: name,
            kind: kind,
            category: category,
            readMode: canRead ? .auto : .manual,
            note: planNote(key: key, byShape: byShape, byName: byName, url: url, typedName: typedName),
            noteIcon: planNoteIcon(key: key, hasUrl: hasUrl, known: known),
            wantsAddress: !hasUrl && !canRead,
            spendUrl: hasUrl ? url : nil,
            jsonPath: hasUrl ? trimmed(jsonPath) : nil,
            header: hasUrl ? trimmed(header) : nil,
            measures: hasUrl ? trimmed(measures) ?? "rate" : nil
        )
    }

    private static func trimmed(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    /// The name the new provider is filed under: what you typed, or the best
    /// short answer available — the provider's own name, the address's host — and
    /// numbered only when that name is already taken.
    static func resolvedName(typed: String, known: Provider?, url: String, existing: [String]) -> String {
        let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty
            ? (known?.label ?? host(of: url) ?? "New provider")
            : trimmed

        let taken = Set(existing.map { words(in: $0).joined() })
        guard taken.contains(words(in: base).joined()) else { return base }
        var number = 2
        while taken.contains(words(in: "\(base) \(number)").joined()) { number += 1 }
        return "\(base) \(number)"
    }

    /// The name to file a provider under when nobody gave one and there is an
    /// address: the address says what it is better than "New provider" does.
    static func host(of url: String) -> String? {
        guard let parsed = URL(string: url), let host = parsed.host, !host.isEmpty else { return nil }
        return host
    }

    /// The one line under the key field — always true, and never asking anyone
    /// to know a provider's internals.
    private static func planNote(
        key: String?,
        byShape: Provider?,
        byName: Provider?,
        url: String,
        typedName: String
    ) -> String {
        if !url.isEmpty {
            let suffix = key == nil
                ? ""
                : " The key you pasted is sent as a Bearer token unless you name another header."
            let over = byShape.map { " \($0.label) shapes are recognised, but the address you give is the one BurnFuse reads." } ?? ""
            return "BurnFuse will read the number at that address, every minute." + suffix + over
        }
        if let byShape {
            return "That looks like \(article(byShape.label)) \(byShape.label) key. \(byShape.readHint)"
        }
        if let byName {
            if byName.canReadLive {
                return "Reading \(byName.label)'s spend needs one of its own keys — paste it and BurnFuse reads this every minute."
            }
            return byName.readHint
        }
        if key != nil {
            return "BurnFuse does not know this key by its shape. Give it an address to read, or type its spend on the row."
        }
        if !typedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Yours to name. Give it an address to read, or type its spend on the row."
        }
        return "Paste the key you already use — BurnFuse watches that same key. Or name a provider and type its spend."
    }

    private static func planNoteIcon(key: String?, hasUrl: Bool, known: Provider?) -> String? {
        if hasUrl { return "arrow.clockwise" }
        if known != nil { return "sparkle" }
        if key != nil { return "questionmark.circle" }
        return nil
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

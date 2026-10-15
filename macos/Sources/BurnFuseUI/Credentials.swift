import Foundation

/// Local-only storage for the read-only provider keys BurnFuse uses to pull
/// live spend.
///
/// Keys live in `~/.burnfuse/keys.json`, written with owner-only permissions.
/// They are never written into `state.json`, never shown in a screenshot, and
/// never sent anywhere except the provider you pointed BurnFuse at.
///
/// What you saved here wins, and the environment is the fallback.
///
/// The other way round was a bug report waiting to happen: an app launched from
/// a terminal (or by anything that keeps that shell's environment) inherits
/// every export in it, so a sample value like `your_openrouter_api_key_here`
/// silently replaced the real key the user had just pasted and saved — and the
/// provider then said the key was invalid, about a key the user never entered.
/// A key you saved yourself in this app is an explicit instruction; it does not
/// get overridden by a variable you have forgotten about. Inject a key without
/// saving one and it is still used, because nothing outranks it.
public enum Credentials {

    /// The environment variable that can supply a provider's key, if any.
    public static func environmentVariable(for provider: String) -> String? {
        switch provider {
        case "openai": return "OPENAI_ADMIN_KEY"
        case "openrouter": return "OPENROUTER_API_KEY"
        case "anthropic": return "ANTHROPIC_ADMIN_KEY"
        case "replicate": return "REPLICATE_API_TOKEN"
        case "groq": return "GROQ_API_KEY"
        case "aws": return "AWS_ACCESS_KEY_ID"
        default: return nil
        }
    }

    public static func fileURL() -> URL {
        if let override = ProcessInfo.processInfo.environment["BURNFUSE_KEYS"] {
            return URL(fileURLWithPath: override)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".burnfuse/keys.json")
    }

    /// Where a provider's key came from. Shown in Settings, because "the key I
    /// pasted does not work" is usually this question, answered wrongly.
    public enum KeySource: Equatable, Sendable {
        /// The key you pasted and saved here. This one always wins.
        case stored
        /// Saved here, but it is the stand-in from a sample file, not a key.
        case storedPlaceholder
        /// From an environment variable — used only because nothing is saved.
        case environment(variable: String)
        /// An environment variable holding the stand-in from a sample file.
        case environmentPlaceholder(variable: String)
        /// Nothing usable to read with.
        case none
    }

    /// The key BurnFuse would send for a provider, and where it came from.
    public struct Resolution: Equatable, Sendable {
        public let key: String?
        public let source: KeySource

        public init(key: String?, source: KeySource) {
            self.key = key
            self.source = source
        }
    }

    /// Resolve a provider's key, once, with its provenance.
    ///
    /// A value that is recognisably a stand-in is never returned as a key, from
    /// either place. Sending `your_key_here` to a provider earns a 401, and a
    /// 401 reads as "your key is wrong" — a sentence about a key that was never
    /// a key. The source says which stand-in it was instead.
    public static func resolve(for provider: String) -> Resolution {
        let stored = sanitize(readAll()[provider] ?? "")
        let variable = environmentVariable(for: provider)
        let fromEnvironment = variable.flatMap {
            sanitize(ProcessInfo.processInfo.environment[$0] ?? "")
        }

        if let stored, !KeyShape.looksLikeAPlaceholder(stored) {
            return Resolution(key: stored, source: .stored)
        }
        if let variable, let value = fromEnvironment, !KeyShape.looksLikeAPlaceholder(value) {
            return Resolution(key: value, source: .environment(variable: variable))
        }
        if stored != nil {
            return Resolution(key: nil, source: .storedPlaceholder)
        }
        if let variable, fromEnvironment != nil {
            return Resolution(key: nil, source: .environmentPlaceholder(variable: variable))
        }
        return Resolution(key: nil, source: .none)
    }

    // MARK: - Keys by slot

    /// A key belongs to the provider *entry* you created — the thing with a name,
    /// a cap, a category and its own row — not to a provider in the abstract.
    /// Two entries can be two different accounts at the same provider, and one
    /// must never read with the other's key.
    ///
    /// An entry's id is its slot. A provider kind is still a slot for keys saved
    /// before entries existed, and for the environment: with nothing saved under
    /// the entry, resolution falls through to the kind, so a key somebody stored
    /// this morning keeps working without a migration step. An entry that *has*
    /// its own key always wins over the kind's.
    public static func resolve(forSlot slot: String, kind: String) -> Resolution {
        guard slot != kind else { return resolve(for: kind) }

        let stored = sanitize(readAll()[slot] ?? "")
        if let stored, !KeyShape.looksLikeAPlaceholder(stored) {
            return Resolution(key: stored, source: .stored)
        }
        if stored != nil {
            return Resolution(key: nil, source: .storedPlaceholder)
        }
        return resolve(for: kind)
    }

    /// The key a watched entry reads with, and where it came from.
    public static func resolve(for entry: BurnKey) -> Resolution {
        resolve(forSlot: entry.id, kind: entry.provider)
    }

    /// The key for a provider, or nothing when there is none to read with.
    public static func key(for provider: String) -> String? {
        resolve(for: provider).key
    }

    /// The key of one entry, or nothing when there is none to read with.
    public static func key(for entry: BurnKey) -> String? {
        resolve(for: entry).key
    }

    /// Where one entry's key comes from, for the row that has to say so.
    public static func source(for entry: BurnKey) -> KeySource {
        resolve(for: entry).source
    }

    /// The two ends of one entry's key, for the row that shows which key is in
    /// use without showing the key.
    public static func masked(for entry: BurnKey) -> String? {
        key(for: entry).map(mask)
    }

    /// Where this provider's key comes from, for the row that has to say so.
    public static func source(for provider: String) -> KeySource {
        resolve(for: provider).source
    }

    /// A key you can recognise without it being usable: the two ends only, with
    /// the middle dropped. Shown in Settings next to "Stored", so the chip means
    /// something specific rather than being a black box.
    public static func masked(for provider: String) -> String? {
        guard let key = key(for: provider) else { return nil }
        return mask(key)
    }

    /// The masked form of a key. A short value is deliberately *less* revealing
    /// rather than more — there is nothing to recognise in it anyway.
    public static func mask(_ key: String) -> String {
        guard key.count > 8 else { return String(key.prefix(2)) + "…" }
        return "\(key.prefix(4))…\(key.suffix(4))"
    }

    public static func hasAny() -> Bool {
        // A key that cannot be read with is not a key. A file full of
        // placeholders must not make the app look set up.
        let stored = readAll()
        let ids = Set(Providers.all.map(\.id)).union(stored.keys)
        return ids.contains { resolve(for: $0).key != nil }
    }

    /// Store (or clear, when empty) the key BurnFuse reads with.
    public static func set(_ value: String?, for slot: String) {
        var all = readAll()
        let cleaned = sanitize(value ?? "")
        if cleaned == nil {
            all.removeValue(forKey: slot)
        } else {
            all[slot] = cleaned
        }
        write(all)
    }

    /// Normalise a pasted key so the junk people actually paste becomes a key
    /// the provider will accept:
    ///
    ///   - surrounding whitespace and newlines from a copy-paste
    ///   - a `Bearer ` scheme already on the clipboard
    ///   - wrapping quotes, straight, smart, or mismatched, from a JSON file or
    ///     a chat message
    ///
    /// A real key cannot carry any of those, so stripping them can only ever
    /// help. They arrive together in either order — `"Bearer sk-…"` — so this
    /// keeps going until nothing more comes off. Returns nil when nothing is
    /// left.
    public static func sanitize(_ raw: String) -> String? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return nil }

        let schemes = ["Bearer ", "bearer ", "BEARER ", "Token ", "token ", "TOKEN "]
        let quotes: Set<Character> = ["\"", "'", "\u{201C}", "\u{201D}", "\u{2018}", "\u{2019}", "«", "»"]

        var changed = true
        while changed {
            changed = false

            for scheme in schemes where value.hasPrefix(scheme) {
                value = value.dropFirst(scheme.count).trimmingCharacters(in: .whitespaces)
                changed = true
            }

            if value.count > 1,
               let first = value.first, let last = value.last,
               quotes.contains(first), quotes.contains(last) {
                value = String(value.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                changed = true
            }
        }

        // An inner newline is always a mis-paste of two things, and would make
        // the request itself malformed.
        value = value
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")

        return value.isEmpty ? nil : value
    }

    // MARK: - Disk

    private static func readAll() -> [String: String] {
        guard let data = try? Data(contentsOf: fileURL()),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else { return [:] }
        return object
    }

    private static func write(_ values: [String: String]) {
        let url = fileURL()
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        guard !values.isEmpty else {
            try? FileManager.default.removeItem(at: url)
            return
        }

        guard let data = try? JSONSerialization.data(
            withJSONObject: values,
            options: [.prettyPrinted, .sortedKeys]
        ) else { return }

        do {
            try data.write(to: url, options: .atomic)
            // Owner-only: these are secrets.
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: url.path
            )
        } catch {
            // Best effort — a failure here just means live reads will not persist.
        }
    }
}

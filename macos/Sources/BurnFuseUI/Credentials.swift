import Foundation

/// Local-only storage for the read-only provider keys BurnFuse uses to pull
/// live spend.
///
/// Keys live in `~/.burnfuse/keys.json`, written with owner-only permissions.
/// They are never written into `state.json`, never shown in a screenshot, and
/// never sent anywhere except the provider you pointed BurnFuse at.
///
/// An environment variable wins over the stored file, so a key can be injected
/// without the app ever persisting it.
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

    /// The key for a provider, preferring the environment over the local file.
    public static func key(for provider: String) -> String? {
        if let name = environmentVariable(for: provider),
           let value = sanitize(ProcessInfo.processInfo.environment[name] ?? "") {
            return value
        }
        let stored = sanitize(readAll()[provider] ?? "")
        return stored
    }

    /// Whether this provider's key came from the environment rather than the
    /// key file. The settings row says so: a key you cannot see being quietly
    /// overridden is a "my pasted key does not work" bug report waiting to
    /// happen.
    public static func isFromEnvironment(for provider: String) -> Bool {
        guard let name = environmentVariable(for: provider) else { return false }
        return sanitize(ProcessInfo.processInfo.environment[name] ?? "") != nil
    }

    public static func hasAny() -> Bool {
        !readAll().isEmpty
            || Providers.all.contains { provider in
                guard let name = environmentVariable(for: provider.id) else { return false }
                return sanitize(ProcessInfo.processInfo.environment[name] ?? "") != nil
            }
    }

    /// Store (or clear, when empty) a provider's key.
    public static func set(_ value: String?, for provider: String) {
        var all = readAll()
        let cleaned = sanitize(value ?? "")
        if cleaned == nil {
            all.removeValue(forKey: provider)
        } else {
            all[provider] = cleaned
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

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
           let value = ProcessInfo.processInfo.environment[name],
           !value.isEmpty {
            return value
        }
        let stored = readAll()[provider]
        return (stored?.isEmpty == false) ? stored : nil
    }

    public static func hasAny() -> Bool {
        !readAll().isEmpty
            || Providers.all.contains { provider in
                guard let name = environmentVariable(for: provider.id) else { return false }
                return !(ProcessInfo.processInfo.environment[name]?.isEmpty ?? true)
            }
    }

    /// Store (or clear, when empty) a provider's key.
    public static func set(_ value: String?, for provider: String) {
        var all = readAll()
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            all.removeValue(forKey: provider)
        } else {
            all[provider] = trimmed
        }
        write(all)
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
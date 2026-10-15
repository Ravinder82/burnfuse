import Foundation

/// Is the key the user just pasted likely to work with this provider?
///
/// Deliberately narrow. It only flags shapes it is sure are wrong — a regular
/// project key where an Admin key is required, or an OpenAI key pasted into the
/// OpenRouter row. Anything it does not recognise is left alone: crying wolf is
/// how people learn to ignore warnings, and the provider will say plainly if a
/// key is genuinely bad.
public struct KeyVerdict: Equatable, Sendable {
    public enum Severity: Equatable, Sendable {
        case fine
        case warning
    }

    public var severity: Severity
    public var message: String?

    public init(severity: Severity, message: String? = nil) {
        self.severity = severity
        self.message = message
    }

    public var isFine: Bool { severity == .fine }
}

public enum KeyShape {

    /// A key we have nothing to say about.
    public static let fine = KeyVerdict(severity: .fine)

    /// Check a pasted key against what the provider actually accepts.
    public static func check(_ raw: String, for provider: String) -> KeyVerdict {
        guard let key = Credentials.sanitize(raw), !key.isEmpty else {
            // Nothing to judge yet — an empty field is not a mistake.
            return fine
        }

        switch provider {
        case "openai":
            if !key.hasPrefix("sk-admin-"), key.hasPrefix("sk-") {
                return KeyVerdict(
                    severity: .warning,
                    message: "That looks like a standard OpenAI key. The costs API only answers to an Admin key, which starts with sk-admin-."
                )
            }

        case "openrouter":
            if !key.hasPrefix("sk-or-"), key.hasPrefix("sk-") {
                return KeyVerdict(
                    severity: .warning,
                    message: "That looks like an OpenAI key. OpenRouter keys start with sk-or-."
                )
            }

        case "anthropic":
            if !key.hasPrefix("sk-ant-admin"), key.hasPrefix("sk-ant-api") {
                return KeyVerdict(
                    severity: .warning,
                    message: "That is a standard Anthropic key. Only an Admin key can read spend."
                )
            }

        default:
            break
        }

        // Unrecognised shapes stay quiet: the provider has the last word.
        return fine
    }
}

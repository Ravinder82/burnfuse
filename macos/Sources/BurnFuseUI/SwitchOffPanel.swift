import SwiftUI

/// The panel that switches a key off at the provider — the only action in this
/// app that stops money, so it is written to be read before it is pressed.
///
/// It shows the account's keys exactly as the provider describes them (name and
/// the key's own redaction — never a full key, which BurnFuse does not have and
/// does not ask for), says which verb this provider uses, and asks for a second
/// press before anything happens. Where the app cannot do it at all, it says so
/// and points at the console instead of failing with the provider's 403.
struct SwitchOffPanel: View {
    /// The watched key whose row this panel is anchored to — so "Hide" closes
    /// the panel in the place it was opened.
    let keyID: String
    let provider: Provider
    @ObservedObject var model: AppModel

    /// The key whose confirmation is showing, if any. A destructive action gets
    /// a second press, in place, with the consequence written on it.
    @State private var confirming: Revoke.AccountKey?

    private var ability: Revoke.Ability { Revoke.ability(for: provider.id) }
    private var keys: [Revoke.AccountKey] { model.accountKeys[provider.id] ?? [] }
    private var message: String? { model.accountKeysMessage[provider.id] }
    private var isLoading: Bool { model.listingAccountKeys.contains(provider.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(spacing: DS.Space.sm) {
                Image(systemName: "switch.2")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Switch a key off at \(provider.label)")
                    .font(.caption.weight(.semibold))
                Spacer(minLength: DS.Space.sm)
                if ability.canSwitchOff {
                    LinkButton(isLoading ? "Asking…" : "Reload") {
                        Task { await model.loadAccountKeys(provider.id) }
                    }
                }
                LinkButton("Hide") { model.showSwitchOffPanel(keyID: nil) }
            }

            NoteText(Revoke.explainer(for: provider.id),
                 icon: ability.canSwitchOff ? "checkmark.shield" : "info.circle",
                 tone: AnyShapeStyle(.tertiary))

            if let outcome = model.switchOffOutcome {
                NoteText(outcome.message,
                     icon: outcome.ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                     tone: outcome.ok ? AnyShapeStyle(DS.Tone.calm) : AnyShapeStyle(DS.Tone.watch))
            }

            if ability.canSwitchOff {
                if let message {
                    NoteText(message, icon: "exclamationmark.triangle.fill", tone: AnyShapeStyle(DS.Tone.watch))
                }
                if isLoading && keys.isEmpty {
                    NoteText("Asking \(provider.label) for this account's keys…", icon: "ellipsis.circle",
                         tone: AnyShapeStyle(.secondary))
                }
                if !keys.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(keys.enumerated()), id: \.element.id) { index, accountKey in
                            if index > 0 { Divider() }
                            row(accountKey)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                            .fill(Color(nsColor: .textBackgroundColor).opacity(0.35))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                            .strokeBorder(Color(nsColor: .separatorColor).opacity(0.6))
                    )
                }
            } else if let whereToRevoke = provider.whereToRevoke {
                NoteText("Switch it off at \(whereToRevoke).", icon: "arrow.up.right.square",
                     tone: AnyShapeStyle(.secondary))
            }
        }
        .padding(DS.Space.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.medium, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.medium, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.7))
        )
        .task(id: provider.id) {
            if ability.canSwitchOff, model.accountKeys[provider.id] == nil {
                await model.loadAccountKeys(provider.id)
            }
        }
    }

    // MARK: One account key

    @ViewBuilder
    private func row(_ accountKey: Revoke.AccountKey) -> some View {
        let isMine = Revoke.isTheKeyBurnFuseUses(accountKey, localKey: Credentials.resolve(for: provider.id).key)
        let isWorking = model.switchingOffKeyID == accountKey.id

        VStack(alignment: .leading, spacing: DS.Space.xs) {
            HStack(alignment: .firstTextBaseline, spacing: DS.Space.sm) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: DS.Space.xs) {
                        Text(accountKey.name)
                            .font(.callout)
                            .lineLimit(1)
                        if isMine {
                            // The one thing worth spotting at a glance: this is
                            // the key the readings come from.
                            Text("BurnFuse reads with this one")
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(DS.accent.opacity(0.18)))
                                .foregroundStyle(DS.accent)
                        }
                        if accountKey.isInactive {
                            Text(accountKey.status ?? "inactive")
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color(nsColor: .quaternaryLabelColor).opacity(0.3)))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(subtitle(for: accountKey))
                        .font(DS.Font.monoSmall)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: DS.Space.sm)

                if !accountKey.isInactive {
                    SecondaryButton(isWorking ? "Working…" : Revoke.switchOffVerb(for: provider.id),
                                    enabled: model.switchingOffKeyID == nil) {
                        confirming = confirming?.id == accountKey.id ? nil : accountKey
                    }
                }
            }

            if confirming?.id == accountKey.id {
                confirmation(accountKey, isMine: isMine)
            }
        }
        .padding(DS.Space.sm)
    }

    private func subtitle(for accountKey: Revoke.AccountKey) -> String {
        var parts = [accountKey.hint]
        if let lastUsed = accountKey.lastUsed {
            parts.append("last used \(Fmt.ago(lastUsed))")
        } else if let createdAt = accountKey.createdAt {
            parts.append("made \(Fmt.ago(createdAt))")
        }
        return parts.joined(separator: " · ")
    }

    /// The second press, with what will happen written on it.
    @ViewBuilder
    private func confirmation(_ accountKey: Revoke.AccountKey, isMine: Bool) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            NoteText(isMine
                 ? "This is the key BurnFuse reads \(provider.label) spend with. Switching it off stops the readings until you paste a new one — and it cannot be undone here."
                 : "\(Revoke.switchOffVerb(for: provider.id)) \(accountKey.name) (\(accountKey.hint)) at \(provider.label)? It stops working immediately, and this cannot be undone here.",
                 icon: "exclamationmark.triangle.fill",
                 tone: AnyShapeStyle(DS.Tone.watch))

            HStack(spacing: DS.Space.sm) {
                SecondaryButton(model.switchingOffKeyID == accountKey.id ? "Working…" : "Yes, \(Revoke.switchOffVerb(for: provider.id).lowercased()) it",
                                tint: DS.Tone.breach,
                                enabled: model.switchingOffKeyID == nil) {
                    Task {
                        await model.switchOff(accountKey, providerID: provider.id)
                        confirming = nil
                    }
                }
                LinkButton("Cancel") { confirming = nil }
                Spacer(minLength: 0)
            }
        }
    }
}

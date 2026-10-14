import SwiftUI

/// Settings: the whole app's configuration in one scroll. Keys, sensitivity,
/// alerts, and the CLI hand-off — nothing hidden behind submenus.
public struct SettingsView: View {
    @ObservedObject var model: AppModel
    var width: CGFloat = 460
    var scrollable: Bool = true

    @State private var newName: String = ""
    @State private var newProvider: String = "openai"
    @State private var newCap: String = "5"
    @State private var webhookDraft: String = ""

    public init(model: AppModel, width: CGFloat = 460, scrollable: Bool = true) {
        self.model = model
        self.width = width
        self.scrollable = scrollable
    }

    public var body: some View {
        Group {
            if scrollable {
                ScrollView { content }
            } else {
                content
            }
        }
        .frame(width: width)
        .onAppear { webhookDraft = model.state.settings.notifyWebhook }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: DS.Space.lg) {
            keysSection
            sensitivitySection
            alertsSection
            cliSection
            aboutSection
        }
        .padding(DS.Space.lg)
    }

    // MARK: Keys

    private var keysSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            SectionHeader("Keys", subtitle: "What BurnFuse watches for you")

            if model.state.entries.isEmpty {
                Card { EmptyKeys() }
            } else {
                VStack(spacing: DS.Space.sm) {
                    ForEach(model.state.entries) { key in
                        Card(padding: DS.Space.md) {
                            keyRow(key)
                        }
                    }
                }
            }

            Card(padding: DS.Space.md) {
                VStack(alignment: .leading, spacing: DS.Space.sm) {
                    Text("Add a key").font(.subheadline.weight(.semibold))
                    HStack(spacing: DS.Space.sm) {
                        TextField("Name", text: $newName)
                            .textFieldStyle(.roundedBorder)
                        Picker("", selection: $newProvider) {
                            ForEach(Providers.all) { provider in
                                Text(provider.label).tag(provider.id)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                    }
                    HStack(spacing: DS.Space.sm) {
                        HStack(spacing: DS.Space.xs) {
                            Text("Cap").font(.caption).foregroundStyle(.secondary)
                            TextField("5", text: $newCap)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 70)
                            Text("$/hr").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        PrimaryButton("Add", enabled: !newName.trimmingCharacters(in: .whitespaces).isEmpty) { addKey() }
                    }
                }
            }
        }
    }

    private func keyRow(_ key: BurnKey) -> some View {
        let assessment = model.assessment(for: key)
        let tone = DS.Tone.forAssessment(overCap: assessment.overCap, spike: assessment.spike)
        return VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(spacing: DS.Space.sm) {
                Image(systemName: Providers.provider(for: key.provider).symbol)
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(key.name).font(.subheadline.weight(.semibold))
                    Text(Providers.label(for: key.provider)).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Text(Fmt.perHour(key.lastReading)).font(DS.Font.mono).foregroundStyle(tone)
                IconButton("trash", help: "Remove \(key.name)") { model.remove(keyID: key.id) }
            }

            HStack(spacing: DS.Space.sm) {
                Text("Cap").font(.caption).foregroundStyle(.secondary)
                TextField("5", value: Binding(
                    get: { key.hourlyLimit },
                    set: { model.setCap(keyID: key.id, cap: max(0.01, $0)) }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 70)
                Text("$/hr").font(.caption).foregroundStyle(.secondary)

                Spacer()

                Toggle("Auto-cut", isOn: Binding(
                    get: { key.autoKill },
                    set: { model.setAutoKill(keyID: key.id, enabled: $0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .font(.caption)
            }
        }
    }

    // MARK: Sensitivity

    private var sensitivitySection: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                SectionHeader("Sensitivity", subtitle: "How far above normal a spike has to be")
                HStack {
                    Slider(
                        value: Binding(
                            get: { model.state.settings.zThreshold },
                            set: { value in model.updateSettings { $0.zThreshold = value } }
                        ),
                        in: 1.0...4.0,
                        step: 0.1
                    )
                    Text(String(format: "%.1fσ", model.state.settings.zThreshold))
                        .font(DS.Font.mono)
                        .frame(width: 46, alignment: .trailing)
                }
                Text(plainSensitivity)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var plainSensitivity: String {
        let z = model.state.settings.zThreshold
        if z <= 1.6 { return "Very sensitive. Flags even small jumps — more alerts, fewer surprises." }
        if z >= 3.0 { return "Relaxed. Only loud spikes get through." }
        return "Balanced. Catches real runaway loops without crying wolf."
    }

    // MARK: Alerts

    private var alertsSection: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                SectionHeader("Alerts", subtitle: "Optional. Ping a Slack or Discord webhook when a key trips")
                HStack(spacing: DS.Space.sm) {
                    TextField("https://hooks.slack.com/…", text: $webhookDraft)
                        .textFieldStyle(.roundedBorder)
                    SecondaryButton("Save") {
                        model.updateSettings { $0.notifyWebhook = webhookDraft.trimmingCharacters(in: .whitespaces) }
                    }
                }
                Toggle("Cut the power automatically when a key trips", isOn: Binding(
                    get: { model.state.settings.autoKillOnBreach },
                    set: { value in model.updateSettings { $0.autoKillOnBreach = value } }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(.caption)
            }
        }
    }

    // MARK: CLI

    private var cliSection: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                SectionHeader("Terminal", subtitle: "The same data, scriptable")
                Text("This app and the CLI read one file, so anything you do in the terminal shows up here in seconds.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: DS.Space.sm) {
                    Text("npx burnfuse status")
                        .font(DS.Font.mono)
                        .padding(.horizontal, DS.Space.sm)
                        .padding(.vertical, DS.Space.xs)
                        .background(RoundedRectangle(cornerRadius: DS.Radius.small).fill(Color(nsColor: .textBackgroundColor)))
                    LinkButton("Copy") { copy("npx burnfuse status") }
                }
                Text(displayPath)
                    .font(DS.Font.monoSmall)
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
        }
    }

    private var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = model.stateURL.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            SectionHeader("About") {
                LinkButton("Load sample data") { model.seedDemoData() }
            }
            Text("burnfuse · a spend breaker for your AI keys. Everything stays on this Mac — no account, no upload, no telemetry.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Actions

    private func addKey() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let cap = Double(newCap) ?? 5
        model.addKey(name: name, provider: newProvider, cap: max(0.01, cap))
        newName = ""
        newCap = "5"
    }

    private func copy(_ text: String) {
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}
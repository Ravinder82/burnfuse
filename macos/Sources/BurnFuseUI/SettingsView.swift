import SwiftUI

/// Settings: the whole app's configuration in one scroll. Keys, live data,
/// sensitivity, and alerts — nothing hidden behind submenus.
public struct SettingsView: View {
    @ObservedObject var model: AppModel
    var width: CGFloat = 460
    var scrollable: Bool = true
    /// Overrides the path shown in the About card. The screenshot renderer
    /// points the model at a throwaway temp file, so it passes the canonical
    /// `~/.burnfuse/state.json` here instead of leaking that temp path.
    var displayStatePath: String? = nil

    @State private var newName: String = ""
    @State private var newProvider: String = "openai"
    @State private var newCap: String = "5"
    @State private var newSpendURL: String = ""
    @State private var newJSONPath: String = ""
    @State private var webhookDraft: String = ""

    @State private var logKeyID: String = ""
    @State private var logCost: String = ""

    @State private var openAIKeyDraft: String = ""
    @State private var openRouterKeyDraft: String = ""
    @State private var keysVersion: Int = 0

    public init(model: AppModel, width: CGFloat = 460, scrollable: Bool = true, displayStatePath: String? = nil) {
        self.model = model
        self.width = width
        self.scrollable = scrollable
        self.displayStatePath = displayStatePath
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
        .onAppear {
            webhookDraft = model.state.settings.notifyWebhook
            if logKeyID.isEmpty { logKeyID = model.state.entries.first?.id ?? "" }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: DS.Space.lg) {
            keysSection
            liveDataSection
            logReadingSection
            sensitivitySection
            alertsSection
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

                    // Custom endpoints can name their own read-only cost URL.
                    if newProvider == "custom" {
                        HStack(spacing: DS.Space.sm) {
                            TextField("https://example.com/cost.json", text: $newSpendURL)
                                .textFieldStyle(.roundedBorder)
                            TextField("data.total", text: $newJSONPath)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 130)
                        }
                        Text("Optional: a URL that returns a dollar amount, and where it sits in the JSON.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
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
                SectionHeader("Sensitivity", subtitle: "How easily a spike should trip the breaker")
                HStack {
                    Text("Calm").font(.caption2).foregroundStyle(.secondary)
                    Slider(
                        value: Binding(
                            get: { model.state.settings.zThreshold },
                            set: { value in model.updateSettings { $0.zThreshold = value } }
                        ),
                        in: 1.0...4.0,
                        step: 0.1
                    )
                    Text("Only big").font(.caption2).foregroundStyle(.secondary)
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

    // MARK: Live data

    /// How the app keeps itself current: read spend straight from the provider,
    /// or paste a number. Both are first-class; neither needs a terminal.
    private var liveDataSection: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                SectionHeader("Live data", subtitle: "Pull spend straight from the provider") {
                    LinkButton("Refresh now") { Task { await model.refreshLive() } }
                }
                Text("BurnFuse reads a read-only cost figure with a key you paste here. Keys are stored on this Mac only, owner-readable, and never leave it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                credentialField(
                    "OpenAI admin key",
                    hint: "Used for the organization costs API.",
                    draft: $openAIKeyDraft,
                    provider: "openai"
                )
                credentialField(
                    "OpenRouter key",
                    hint: "Reads live credit usage.",
                    draft: $openRouterKeyDraft,
                    provider: "openrouter"
                )

                Text("Read every 60 seconds while BurnFuse is running. OpenRouter needs a standard key; OpenAI needs an Admin key.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .id(keysVersion)
    }

    private func credentialField(_ label: String, hint: String, draft: Binding<String>, provider: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            HStack(spacing: DS.Space.sm) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if Credentials.key(for: provider) != nil {
                    StatusChip(text: "Set", systemImage: "checkmark.seal.fill", tone: DS.Tone.calm)
                }
            }
            HStack(spacing: DS.Space.sm) {
                SecureField(hint, text: draft)
                    .textFieldStyle(.roundedBorder)
                SecondaryButton("Save") { saveCredential(provider: provider, value: draft.wrappedValue, draft: draft) }
                if Credentials.key(for: provider) != nil {
                    IconButton("trash", help: "Remove \(label)") {
                        Credentials.set(nil, for: provider)
                        draft.wrappedValue = ""
                        keysVersion += 1
                    }
                }
            }
        }
    }

    private func saveCredential(provider: String, value: String, draft: Binding<String>) {
        Credentials.set(value, for: provider)
        draft.wrappedValue = ""
        keysVersion += 1
        Task { await model.refreshLive() }
    }

    // MARK: Log a reading

    private var logReadingSection: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                SectionHeader("Log a reading", subtitle: "Type what a key is spending per hour right now")
                if model.state.entries.isEmpty {
                    Text("Add a key first, then log its burn here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: DS.Space.sm) {
                        Picker("", selection: $logKeyID) {
                            ForEach(model.state.entries) { key in
                                Text(key.name).tag(key.id)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 200)

                        HStack(spacing: DS.Space.xs) {
                            Text("$").font(.caption).foregroundStyle(.secondary)
                            TextField("1.20", text: $logCost)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            Text("/hr").font(.caption).foregroundStyle(.secondary)
                        }

                        Spacer()

                        PrimaryButton("Log", enabled: Double(logCost) != nil) { logReading() }
                    }
                }
                if let message = model.lastReadMessage {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
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
            Text(displayPath)
                .font(DS.Font.monoSmall)
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
        }
    }

    private var displayPath: String {
        if let displayStatePath { return displayStatePath }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = model.stateURL.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    // MARK: Actions

    private func addKey() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let cap = Double(newCap) ?? 5
        let key = model.addKey(name: name, provider: newProvider, cap: max(0.01, cap))
        if newProvider == "custom" && (!newSpendURL.isEmpty || !newJSONPath.isEmpty) {
            model.setSource(keyID: key.id, spendUrl: newSpendURL, jsonPath: newJSONPath)
        }
        newName = ""
        newCap = "5"
        newSpendURL = ""
        newJSONPath = ""
    }

    private func logReading() {
        guard let cost = Double(logCost), !logKeyID.isEmpty else { return }
        model.record(keyID: logKeyID, cost: max(0, cost))
        logCost = ""
    }
}
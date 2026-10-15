import SwiftUI

/// Settings: the whole app's configuration in one scroll. Keys, provider
/// credentials, live data, sensitivity, and alerts — nothing hidden behind
/// submenus.
public struct SettingsView: View {
    @ObservedObject var model: AppModel
    var width: CGFloat? = 460
    var scrollable: Bool = true
    /// Overrides the path shown in the About card. The screenshot renderer
    /// points the model at a throwaway temp file, so it passes the canonical
    /// `~/.burnfuse/state.json` here instead of leaking that temp path.
    var displayStatePath: String? = nil
    /// Seeds the key fields for an offscreen render only, so a screenshot can
    /// show a key being pasted and tested. Never set in the running app.
    var previewKeyDrafts: [String: String] = [:]

    @State private var newName: String = ""
    @State private var newProvider: String = "openai"
    @State private var newCap: String = "5"
    @State private var newSpendURL: String = ""
    @State private var newJSONPath: String = ""
    @State private var newHeader: String = ""
    @State private var newMeasures: String = "rate"
    @State private var webhookDraft: String = ""

    @State private var logKeyID: String = ""
    @State private var logCost: String = ""

    /// One draft per provider, so the credential rows are generated from the
    /// provider list rather than hand-written one at a time.
    @State private var keyDrafts: [String: String] = [:]
    @State private var keysVersion: Int = 0

    public init(model: AppModel, width: CGFloat? = 460, scrollable: Bool = true,
                displayStatePath: String? = nil, previewKeyDrafts: [String: String] = [:]) {
        self.model = model
        self.width = width
        self.scrollable = scrollable
        self.displayStatePath = displayStatePath
        self.previewKeyDrafts = previewKeyDrafts
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
        .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
        .onAppear {
            webhookDraft = model.state.settings.notifyWebhook
            if logKeyID.isEmpty { logKeyID = model.state.entries.first?.id ?? "" }
            if keyDrafts.isEmpty { keyDrafts = previewKeyDrafts }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: DS.Space.lg) {
            keysSection
            providerKeysSection
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
                    Text("Watch a key").font(.subheadline.weight(.semibold))
                    Text("Name the thing you want a breaker on, then give it a cap in dollars an hour.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
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

                    // A custom endpoint names its own read-only cost URL.
                    if newProvider == "custom" {
                        customEndpointFields
                    }
                }
            }
        }
    }

    /// The extra fields a custom endpoint needs: where to read, where the dollar
    /// figure sits, how to send the key, and whether it counts up.
    private var customEndpointFields: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(spacing: DS.Space.sm) {
                TextField("https://example.com/cost.json", text: $newSpendURL)
                    .textFieldStyle(.roundedBorder)
                TextField("data.total", text: $newJSONPath)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 130)
            }
            if let warning = urlWarning {
                Text(warning)
                    .font(.caption2)
                    .foregroundStyle(DS.Tone.watch)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: DS.Space.sm) {
                Text("Header").font(.caption).foregroundStyle(.secondary)
                TextField("Authorization", text: $newHeader)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 130)
                Spacer(minLength: DS.Space.sm)
                Picker("", selection: $newMeasures) {
                    Text("Reports a rate").tag("rate")
                    Text("Counts up").tag("total")
                }
                .labelsHidden()
                .frame(width: 150)
            }
            Text("A URL that returns a dollar amount, and where it sits in the JSON. The key is sent as Bearer under Authorization, or on its own under any other header you name — that is how an endpoint wanting x-api-key gets wired up. If it counts money up rather than reporting an hourly figure, say so and BurnFuse will work the rate out from two reads.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
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

    // MARK: Provider credentials

    /// How the app keeps itself current: read spend straight from the provider,
    /// or paste a number. Both are first-class; neither needs a terminal.
    ///
    /// The rows are generated from the provider list, so adding a provider means
    /// adding it there — not a new hand-written block here. Every provider we
    /// know about gets a place to put its key, and every row says plainly what
    /// that key will and will not do.
    private var providerKeysSection: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Space.md) {
                SectionHeader("Provider keys", subtitle: "What BurnFuse reads spend with") {
                    LinkButton(model.isRefreshing ? "Refreshing…" : "Refresh now",
                               enabled: !model.isRefreshing) {
                        Task { await model.refreshLive() }
                    }
                }
                Text("BurnFuse reads a read-only cost figure with a key you paste here. Keys are stored on this Mac only, owner-readable, and never leave it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(Providers.all.filter(\.supportsLiveSpend)) { provider in
                    credentialRow(provider)
                }

                Divider().opacity(0.6)

                Text("These have no public spend read, so a key would do nothing here. Watch the key anyway and log its readings instead — or point a custom endpoint at a number of your own.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(Providers.all.filter { !$0.supportsLiveSpend }) { provider in
                    manualOnlyRow(provider)
                }

                Text("Read every 60 seconds while BurnFuse is running. Providers that count spend up rather than reporting an hourly figure need two reads: the first saves a baseline, the next one gives you a rate.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .id(keysVersion)
    }

    private func credentialRow(_ provider: Provider) -> some View {
        let stored = Credentials.key(for: provider.id)
        let fromEnvironment = Credentials.isFromEnvironment(for: provider.id)
        let draft = keyDrafts[provider.id] ?? ""
        let hasDraft = Credentials.sanitize(draft) != nil
        let verdict = KeyShape.check(draft, for: provider.id)
        let test = model.keyTests[provider.id]

        return VStack(alignment: .leading, spacing: DS.Space.xxs) {
            HStack(spacing: DS.Space.sm) {
                Image(systemName: provider.symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
                Text(provider.label).font(.caption.weight(.medium))
                Spacer()
                if let masked = Credentials.masked(for: provider.id) {
                    Text(masked)
                        .font(DS.Font.monoSmall)
                        .foregroundStyle(.tertiary)
                        .help("The two ends of the stored key, so you can tell which one it is")
                }
                if stored != nil {
                    StatusChip(text: "Stored", systemImage: "checkmark.seal.fill", tone: DS.Tone.calm)
                }
            }

            HStack(spacing: DS.Space.sm) {
                SecureField(provider.keyLabel, text: draftBinding(for: provider.id))
                    .textFieldStyle(.roundedBorder)
                // Save is live only with something in the field: an empty field
                // plus Save used to mean "delete my key" without saying so. The
                // trash button is the one honest way to remove a key.
                SecondaryButton("Save", enabled: hasDraft) { saveCredential(provider: provider) }
                // Test is always live: pressing it with nothing stored gets a
                // sentence about that, which is more use than a dead button. A
                // key already typed but not saved is the one that gets tried.
                SecondaryButton(test?.isTesting == true ? "Testing…" : "Test",
                                enabled: test?.isTesting != true) {
                    Task { await model.testCredential(provider.id, using: draft) }
                }
                if stored != nil {
                    IconButton("trash", help: "Remove the \(provider.label) key") { removeCredential(provider: provider) }
                }
            }

            statusLine(provider: provider, test: test, verdict: verdict,
                       stored: stored, fromEnvironment: fromEnvironment, hasDraft: hasDraft)
        }
    }

    /// The one line under a credential field. The test's verdict comes first —
    /// it is the answer to the question the user actually has — then a warning
    /// about the shape of the key, then what the key is for.
    @ViewBuilder
    private func statusLine(
        provider: Provider,
        test: KeyTest?,
        verdict: KeyVerdict,
        stored: String?,
        fromEnvironment: Bool,
        hasDraft: Bool
    ) -> some View {
        if let test {
            switch test {
            case .testing:
                note("Trying this key with \(provider.label)…", icon: "ellipsis.circle", tone: AnyShapeStyle(.secondary))
            case .working(let message):
                note(message, icon: "checkmark.circle.fill", tone: AnyShapeStyle(DS.Tone.calm))
            case .failed(let message):
                note(message, icon: "exclamationmark.triangle.fill", tone: AnyShapeStyle(DS.Tone.watch))
            }
        } else if verdict.severity == .warning, let message = verdict.message {
            // The wrong kind of key, caught before it costs a failed read.
            note(message, icon: "exclamationmark.triangle.fill", tone: AnyShapeStyle(DS.Tone.watch))
        } else {
            VStack(alignment: .leading, spacing: DS.Space.xxs) {
                note(provider.keyHint, icon: nil, tone: AnyShapeStyle(.tertiary))
                if hasDraft {
                    // A key in the field is not being used for anything yet, and
                    // pressing Test is how you find out it works without first
                    // committing to it.
                    note(stored == nil
                         ? "Press Test to try this key before you save it."
                         : "Press Test to try the key in the field. Save replaces the one stored.",
                         icon: "wand.and.stars", tone: AnyShapeStyle(.tertiary))
                }
                if stored == nil, !hasDraft, let whereToGet = provider.whereToGet {
                    note(whereToGet, icon: "mappin.and.ellipse", tone: AnyShapeStyle(.tertiary))
                }
                if stored != nil, fromEnvironment,
                   let variable = Credentials.environmentVariable(for: provider.id) {
                    note("Using \(variable) from your environment.", icon: "terminal", tone: AnyShapeStyle(.tertiary))
                }
            }
        }
    }

    private func note(_ text: String, icon: String?, tone: AnyShapeStyle) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Space.xs) {
            if let icon {
                Image(systemName: icon).font(.caption2)
            }
            Text(text)
        }
        .font(.caption2)
        .foregroundStyle(tone)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// A provider with no public spend read. No key field on purpose: a Save
    /// button beside "log a reading instead" would be a control that does
    /// nothing, and that is worse than saying plainly what to do.
    private func manualOnlyRow(_ provider: Provider) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            HStack(spacing: DS.Space.sm) {
                Image(systemName: provider.symbol)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(width: 14)
                Text(provider.label).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Spacer()
                Text("Manual only")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.tertiary)
            }
            Text(provider.keyHint)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func draftBinding(for provider: String) -> Binding<String> {
        Binding(
            get: { keyDrafts[provider] ?? "" },
            set: { keyDrafts[provider] = $0 }
        )
    }

    /// macOS blocks a plain-HTTP read before it ever leaves this machine, so a
    /// custom endpoint that would be silently refused should be said out loud
    /// rather than looking like a broken key.
    private var urlWarning: String? {
        let trimmed = newSpendURL.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        guard let url = URL(string: trimmed), url.host?.isEmpty == false else {
            return "That is not a web address a Mac can open."
        }
        if url.scheme?.lowercased() == "http" {
            return "Plain HTTP is blocked by macOS, so this would never be read. Use https, or an address on your own machine."
        }
        return nil
    }

    private func saveCredential(provider: Provider) {
        Credentials.set(keyDrafts[provider.id] ?? "", for: provider.id)
        keyDrafts[provider.id] = ""
        // A different key means the old verdict is about a key that is gone.
        model.keyTests[provider.id] = nil
        keysVersion += 1
        Task { await model.refreshLive() }
    }

    private func removeCredential(provider: Provider) {
        Credentials.set(nil, for: provider.id)
        keyDrafts[provider.id] = ""
        model.keyTests[provider.id] = nil
        keysVersion += 1
    }

    // MARK: Log a reading

    private var logReadingSection: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                SectionHeader("Log a reading", subtitle: "Type what a key is spending per hour right now")
                if model.state.entries.isEmpty {
                    Text("Watch a key first, then log its burn here.")
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
        let isCustom = newProvider == "custom"
        model.addKey(
            name: name,
            provider: newProvider,
            cap: max(0.01, cap),
            spendUrl: isCustom ? newSpendURL : nil,
            jsonPath: isCustom ? newJSONPath : nil,
            header: isCustom ? newHeader : nil,
            measures: isCustom ? newMeasures : nil
        )
        newName = ""
        newCap = "5"
        newSpendURL = ""
        newJSONPath = ""
        newHeader = ""
    }

    private func logReading() {
        guard let cost = Double(logCost), !logKeyID.isEmpty else { return }
        model.record(keyID: logKeyID, cost: max(0, cost))
        logCost = ""
    }
}

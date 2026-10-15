import SwiftUI

/// Settings, built around one idea: **the key you paste is the key you watch.**
///
/// There is no second list of "provider keys" and no separate concept to learn
/// first. Adding a key and watching it are the same action, and every row says
/// in plain words whether BurnFuse reads the number itself or takes it from you.
/// A provider with no readable spend is not a dead end either — the row explains
/// why in one line and takes a typed number right there.
public struct SettingsView: View {
    @ObservedObject var model: AppModel
    var width: CGFloat? = 460
    var scrollable: Bool = true
    /// Overrides the path shown in the About card. The screenshot renderer
    /// points the model at a throwaway temp file, so it passes the canonical
    /// `~/.burnfuse/state.json` here instead of leaking that temp path.
    var displayStatePath: String? = nil
    /// Seeds the add-a-key field for an offscreen render only, so a screenshot
    /// can show a pasted key being recognised. Never set in the running app.
    var previewAddKey: String = ""
    /// Seeds a provider's key field the same way.
    var previewKeyDrafts: [String: String] = [:]

    // Adding a key.
    @State private var newKey: String = ""
    @State private var pickedProvider: String? = nil
    @State private var pickedCategory: Category? = nil
    @State private var capDraft: String = "5"
    @State private var newSpendURL: String = ""
    @State private var newJSONPath: String = ""
    @State private var newHeader: String = ""
    @State private var newMeasures: String = "rate"

    // Per-row state.
    @State private var nameDrafts: [String: String] = [:]
    @State private var keyDrafts: [String: String] = [:]
    @State private var logDrafts: [String: String] = [:]
    @State private var replacing: String? = nil

    @State private var webhookDraft: String = ""

    public init(model: AppModel, width: CGFloat? = 460, scrollable: Bool = true,
                displayStatePath: String? = nil, previewAddKey: String = "",
                previewKeyDrafts: [String: String] = [:]) {
        self.model = model
        self.width = width
        self.scrollable = scrollable
        self.displayStatePath = displayStatePath
        self.previewAddKey = previewAddKey
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
            if newKey.isEmpty { newKey = previewAddKey }
            if keyDrafts.isEmpty { keyDrafts = previewKeyDrafts }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: DS.Space.lg) {
            keysSection
            sensitivitySection
            alertsSection
            aboutSection
        }
        .padding(DS.Space.lg)
    }

    // MARK: - Keys

    /// Your keys, and how to add another. One card, because it is one thing.
    private var keysSection: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Space.md) {
                SectionHeader("Your keys", subtitle: "BurnFuse watches these and trips the breaker when one runs hot.") {
                    LinkButton(model.isRefreshing ? "Reading…" : "Refresh now",
                               enabled: !model.isRefreshing) {
                        Task { await model.refreshLive() }
                    }
                }

                if model.state.entries.isEmpty {
                    EmptyKeys()
                } else {
                    VStack(alignment: .leading, spacing: DS.Space.md) {
                        ForEach(Array(model.state.entries.enumerated()), id: \.element.id) { index, key in
                            if index > 0 { Divider() }
                            keyRow(key)
                        }
                    }
                }

                Divider()

                addKeyBlock
            }
        }
    }

    // MARK: Add a key

    /// The whole add flow: paste a key, and BurnFuse works out the rest. The
    /// provider and the category are pre-filled from the key itself, and the
    /// line underneath says exactly what will happen — before anything is saved.
    private var addKeyBlock: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            Text("Add a key").font(.subheadline.weight(.semibold))

            SecureField("Paste your API key", text: $newKey)
                .textFieldStyle(.roundedBorder)

            detectionLine

            HStack(spacing: DS.Space.sm) {
                providerMenu
                categoryMenu

                Spacer(minLength: DS.Space.sm)

                HStack(spacing: DS.Space.xs) {
                    Text("Cap").font(.caption).foregroundStyle(.secondary)
                    TextField("5", text: $capDraft)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 58)
                    Text("$/hr").font(.caption).foregroundStyle(.secondary)
                }
            }

            if chosenProvider?.id == "custom" {
                endpointFields
            }

            HStack(spacing: DS.Space.sm) {
                Spacer()
                PrimaryButton("Add key", systemImage: "plus", enabled: canAdd) { addKey() }
            }
        }
    }

    /// What BurnFuse makes of what is in the field, as it is typed. This is the
    /// answer to "what will this key do here", and it never asks the user to know
    /// a provider's internals to get it.
    @ViewBuilder
    private var detectionLine: some View {
        if let detected, pickedProvider == nil || pickedProvider == detected.id {
            note("That looks like \(Providers.article(detected.label)) \(detected.label) key. \(detected.readHint)",
                 icon: "sparkle", tone: AnyShapeStyle(.secondary))
        } else if let picked = chosenProvider {
            if let detected, detected.id != picked.id {
                note("That key looks like \(detected.label), but you picked \(picked.label). Pick \(detected.label) from the list if that is the wrong way round.",
                     icon: "exclamationmark.triangle.fill", tone: AnyShapeStyle(DS.Tone.watch))
            } else {
                note(picked.readHint, icon: nil, tone: AnyShapeStyle(.tertiary))
            }
        } else if Credentials.sanitize(newKey) != nil {
            note("BurnFuse does not know this key by its shape. Pick its provider on the left and it will still watch it.",
                 icon: "questionmark.circle", tone: AnyShapeStyle(.tertiary))
        } else {
            note("Paste the key you already use — BurnFuse watches that same key. Nothing to create, nothing to copy twice.",
                 icon: nil, tone: AnyShapeStyle(.tertiary))
        }
    }

    private var providerMenu: some View {
        MenuChip(
            title: chosenProvider?.label ?? "Pick a provider",
            symbol: chosenProvider?.symbol ?? "questionmark.circle",
            emphasised: chosenProvider == nil
        ) {
            ForEach(Providers.categories) { category in
                Section(category.title) {
                    ForEach(Providers.providers(in: category)) { provider in
                        Button(provider.label) {
                            pickedProvider = provider.id
                            pickedCategory = provider.category
                        }
                    }
                }
            }
        }
    }

    private var categoryMenu: some View {
        MenuChip(title: chosenCategory.title, symbol: chosenCategory.symbol) {
            ForEach(Category.allCases) { category in
                Button("\(category.title) — \(category.blurb)") { pickedCategory = category }
            }
        }
    }

    /// The extra fields your own endpoint needs: where to read, where the dollar
    /// figure sits, how to send the key, and whether it counts up.
    private var endpointFields: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(spacing: DS.Space.sm) {
                TextField("https://example.com/cost.json", text: $newSpendURL)
                    .textFieldStyle(.roundedBorder)
                TextField("data.total", text: $newJSONPath)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
            }
            if let warning = urlWarning {
                note(warning, icon: "exclamationmark.triangle.fill", tone: AnyShapeStyle(DS.Tone.watch))
            }
            HStack(spacing: DS.Space.sm) {
                Text("Header").font(.caption).foregroundStyle(.secondary)
                TextField("Authorization", text: $newHeader)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                Spacer(minLength: DS.Space.sm)
                Picker("", selection: $newMeasures) {
                    Text("Reports $/hr").tag("rate")
                    Text("Counts up").tag("total")
                }
                .labelsHidden()
                .frame(width: 150)
            }
            note("Any address that returns a dollar figure works — your own script, a cloud billing export, a page behind a token. BurnFuse sends the key as Bearer under Authorization unless you name another header here.",
                 icon: nil, tone: AnyShapeStyle(.tertiary))
        }
    }

    // MARK: One watched key

    private func keyRow(_ key: BurnKey) -> some View {
        let provider = Providers.provider(for: key.provider)
        let assessment = model.assessment(for: key)
        let tone = DS.Tone.forAssessment(overCap: assessment.overCap, spike: assessment.spike)

        return VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(spacing: DS.Space.sm) {
                Image(systemName: provider.symbol)
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    TextField("Name", text: nameBinding(key))
                        .textFieldStyle(.plain)
                        .font(.subheadline.weight(.semibold))
                    Text("\(key.effectiveCategory.title) · \(provider.label) · \(key.readingSourcePhrase)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: DS.Space.sm)
                Text(Fmt.perHour(key.lastReading)).font(DS.Font.mono).foregroundStyle(tone)
                // Removing a row and revoking a key are different actions, and
                // the moment someone reaches for the first is the moment to name
                // the second.
                IconButton("trash", help: "Stop watching \(key.name). To stop it billing, \(revokeSentence(for: provider))") {
                    model.remove(keyID: key.id)
                }
            }

            BurnMeter(fill: key.capFill, tone: tone)

            HStack(spacing: DS.Space.sm) {
                Text("Cap").font(.caption).foregroundStyle(.secondary)
                TextField("5", value: Binding(
                    get: { key.hourlyLimit },
                    set: { model.setCap(keyID: key.id, cap: max(0.01, $0)) }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 70)
                Text("$/hr").font(.caption).foregroundStyle(.secondary)

                Spacer(minLength: DS.Space.sm)

                Toggle("Pause if it trips", isOn: Binding(
                    get: { key.autoKill },
                    set: { model.setAutoKill(keyID: key.id, enabled: $0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .font(.caption)
                .help("Stops BurnFuse reading this key once it trips. It does not stop the provider billing.")
            }

            readingBlock(key, provider: provider)
        }
    }

    /// How this key's number gets in — the one thing worth reading twice on this
    /// screen, so it always comes with the reason attached.
    @ViewBuilder
    private func readingBlock(_ key: BurnKey, provider: Provider) -> some View {
        if key.isManualRead || !provider.canReadLive {
            manualBlock(key, provider: provider)
        } else {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                if provider.id == "custom" {
                    endpointRow(key)
                }
                liveBlock(key, provider: provider)
            }
        }
    }

    /// Your own endpoint's address, editable on the row itself. A custom key
    /// with no address is a key that can never be read, so this comes first.
    private func endpointRow(_ key: BurnKey) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            HStack(spacing: DS.Space.sm) {
                TextField("https://example.com/cost.json", text: Binding(
                    get: { key.source?.spendUrl ?? "" },
                    set: { model.setSource(keyID: key.id, spendUrl: $0, jsonPath: nil) }
                ))
                .textFieldStyle(.roundedBorder)
                TextField("data.total", text: Binding(
                    get: { key.source?.jsonPath ?? "" },
                    set: { model.setSource(keyID: key.id, spendUrl: nil, jsonPath: $0) }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 110)
            }
            HStack(spacing: DS.Space.sm) {
                TextField("Header — Authorization", text: Binding(
                    get: { key.source?.header ?? "" },
                    set: { model.setSource(keyID: key.id, spendUrl: nil, jsonPath: nil, header: $0) }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)
                Picker("", selection: Binding(
                    get: { key.source?.measures ?? "rate" },
                    set: { model.setSource(keyID: key.id, spendUrl: nil, jsonPath: nil, measures: $0) }
                )) {
                    Text("Reports $/hr").tag("rate")
                    Text("Counts up").tag("total")
                }
                .labelsHidden()
                .frame(width: 130)
                Spacer(minLength: 0)
            }
        }
    }

    /// A key whose spend is typed in. First class, not a failure: several of the
    /// biggest providers publish no cost endpoint at all.
    private func manualBlock(_ key: BurnKey, provider: Provider) -> some View {
        let draft = logDrafts[key.id] ?? ""
        let hint = (provider.canReadLive && key.isManualRead)
            ? "You type this one's spend in yourself."
            : provider.readHint
        return VStack(alignment: .leading, spacing: DS.Space.xs) {
            note(hint, icon: "keyboard", tone: AnyShapeStyle(.tertiary))
            if let whereToRead = provider.whereToRead {
                note("Read it at \(whereToRead).", icon: "mappin.and.ellipse", tone: AnyShapeStyle(.tertiary))
            }

            HStack(spacing: DS.Space.sm) {
                HStack(spacing: DS.Space.xs) {
                    Text("$").font(.caption).foregroundStyle(.secondary)
                    TextField("1.20", text: logBinding(key.id))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text("/hr").font(.caption).foregroundStyle(.secondary)
                }
                SecondaryButton("Save reading", enabled: Double(draft) != nil) { logReading(keyID: key.id) }
                if provider.canReadLive {
                    LinkButton("Read it automatically instead") {
                        model.setReadMode(keyID: key.id, mode: .auto)
                    }
                }
                Spacer(minLength: 0)
            }

            if let message = model.lastMessageByKey[key.id] {
                note(message, icon: "arrow.clockwise", tone: AnyShapeStyle(.tertiary))
            }
        }
    }

    /// A key BurnFuse reads itself. The key is stored once, here, and the row
    /// says which one it is — the two ends of it, never the whole thing.
    @ViewBuilder
    private func liveBlock(_ key: BurnKey, provider: Provider) -> some View {
        let stored = Credentials.key(for: provider.id) != nil
        let fromEnvironment = Credentials.isFromEnvironment(for: provider.id)
        let editing = replacing == provider.id || !stored
        let draft = keyDrafts[provider.id] ?? ""
        let verdict = KeyShape.check(draft, for: provider.id)
        let test = model.keyTests[provider.id]

        VStack(alignment: .leading, spacing: DS.Space.xs) {
            if editing {
                HStack(spacing: DS.Space.sm) {
                    SecureField(provider.keyLabel, text: draftBinding(for: provider.id))
                        .textFieldStyle(.roundedBorder)
                    SecondaryButton("Save", enabled: Credentials.sanitize(draft) != nil) {
                        model.storeCredential(draft, for: provider.id)
                        keyDrafts[provider.id] = ""
                        replacing = nil
                        Task { await model.refreshLive() }
                    }
                    SecondaryButton(test?.isTesting == true ? "Testing…" : "Test",
                                    enabled: test?.isTesting != true) {
                        Task { await model.testCredential(provider.id, using: draft) }
                    }
                    if stored {
                        LinkButton("Cancel") { replacing = nil; keyDrafts[provider.id] = "" }
                    }
                }
            } else {
                HStack(spacing: DS.Space.sm) {
                    if let masked = Credentials.masked(for: provider.id) {
                        Label(masked, systemImage: "checkmark.seal.fill")
                            .font(DS.Font.monoSmall)
                            .foregroundStyle(DS.Tone.calm)
                            .help("The two ends of the stored key, so you can tell which one it is")
                    }
                    Spacer(minLength: DS.Space.sm)
                    LinkButton("Test") { Task { await model.testCredential(provider.id) } }
                    LinkButton("Replace key") { replacing = provider.id }
                    LinkButton("Remove", tint: DS.Tone.breach) {
                        model.storeCredential(nil, for: provider.id)
                    }
                }
            }

            statusLine(key, provider: provider, test: test, verdict: verdict,
                       stored: stored, fromEnvironment: fromEnvironment, hasDraft: draft != "")
        }
    }

    /// The line under a key field, in the order the questions arrive: what the
    /// test found, then whether the key is even the right shape, then what this
    /// key is for and where to get it.
    @ViewBuilder
    private func statusLine(
        _ key: BurnKey,
        provider: Provider,
        test: KeyTest?,
        verdict: KeyVerdict,
        stored: Bool,
        fromEnvironment: Bool,
        hasDraft: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            if let test {
                switch test {
                case .testing:
                    note("Trying this key with \(provider.label)…", icon: "ellipsis.circle", tone: AnyShapeStyle(.secondary))
                case .working(let message):
                    note(message, icon: "checkmark.circle.fill", tone: AnyShapeStyle(DS.Tone.calm))
                case .failed(let message):
                    note(message, icon: "exclamationmark.triangle.fill", tone: AnyShapeStyle(DS.Tone.watch))
                    if !key.isManualRead {
                        // The other way to use this key, offered at the moment the
                        // automatic read is known not to work.
                        LinkButton("Type this key's spend by hand instead") {
                            model.setReadMode(keyID: key.id, mode: .manual)
                        }
                    }
                }
            } else if verdict.severity == .warning, let message = verdict.message {
                // The wrong kind of key, caught before it costs a failed read.
                note(message, icon: "exclamationmark.triangle.fill", tone: AnyShapeStyle(DS.Tone.watch))
            } else if !stored {
                note(provider.readHint, icon: nil, tone: AnyShapeStyle(.tertiary))
                if let whereToGet = provider.whereToGet {
                    note(whereToGet, icon: "mappin.and.ellipse", tone: AnyShapeStyle(.tertiary))
                }
            } else {
                if let message = model.lastMessageByKey[key.id] {
                    note(message, icon: "arrow.clockwise", tone: AnyShapeStyle(.tertiary))
                } else {
                    note("BurnFuse reads this one for you, every minute.", icon: nil, tone: AnyShapeStyle(.tertiary))
                }
                if fromEnvironment, let variable = Credentials.environmentVariable(for: provider.id) {
                    note("Using \(variable) from your environment, which wins over anything saved here.",
                         icon: "terminal", tone: AnyShapeStyle(.tertiary))
                }
            }

            if hasDraft, stored == false {
                note("Press Test to try the key in the field before saving it.", icon: "wand.and.stars", tone: AnyShapeStyle(.tertiary))
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
                Toggle("Pause any key that trips", isOn: Binding(
                    get: { model.state.settings.autoKillOnBreach },
                    set: { value in model.updateSettings { $0.autoKillOnBreach = value } }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(.caption)
                .help("Stops BurnFuse reading a key once it trips. It does not stop the provider billing.")
                // The one thing worth being blunt about, because everything in
                // this app's vocabulary suggests otherwise.
                note("Pausing stops BurnFuse reading a key — nothing more. Only your provider can revoke it, and that is the only thing that stops the billing.",
                     icon: "info.circle",
                     tone: AnyShapeStyle(.tertiary))
            }
        }
    }

    // MARK: About

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

    // MARK: - Add-a-key logic

    private var detected: Provider? { Providers.detect(newKey) }

    /// An explicit pick always wins over a guessed shape, so someone who knows
    /// what they have is never overruled by a prefix.
    private var chosenProvider: Provider? {
        if let pickedProvider { return Providers.provider(for: pickedProvider) }
        return detected
    }

    private var chosenCategory: Category {
        pickedCategory ?? chosenProvider?.category ?? .other
    }

    /// A new key is named after its provider, numbered only when there is
    /// already one of that name. Nobody should have to invent a label to add a
    /// key, and nobody should get two rows called "OpenRouter" either.
    private var suggestedName: String {
        guard let provider = chosenProvider else { return "New key" }
        let existing = model.state.entries.filter { $0.provider == provider.id }.count
        return existing == 0 ? provider.label : "\(provider.label) \(existing + 1)"
    }

    private var canAdd: Bool {
        Credentials.sanitize(newKey) != nil || pickedProvider != nil
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

    private func addKey() {
        guard let provider = chosenProvider else { return }
        let typed = Credentials.sanitize(newKey)
        let isCustom = provider.id == "custom"
        let willRead = provider.canReadLive && typed != nil

        // A pasted key is only stored when something can read with it. Keeping a
        // secret that nothing uses would be a liability with no upside — and the
        // row says so rather than the field quietly doing nothing.
        if willRead, let typed {
            model.storeCredential(typed, for: provider.id)
        }

        model.addKey(
            name: suggestedName,
            provider: provider.id,
            cap: max(0.01, Double(capDraft) ?? 5),
            category: pickedCategory,
            readMode: willRead ? nil : .manual,
            spendUrl: isCustom ? newSpendURL : nil,
            jsonPath: isCustom ? newJSONPath : nil,
            header: isCustom ? newHeader : nil,
            measures: isCustom ? newMeasures : nil
        )

        newKey = ""
        pickedProvider = nil
        pickedCategory = nil
        capDraft = "5"
        newSpendURL = ""
        newJSONPath = ""
        newHeader = ""
        newMeasures = "rate"

        if willRead { Task { await model.refreshLive() } }
    }

    // MARK: - Row helpers

    /// "revoke it at <page>" / "revoke it where you issued it", as a clause.
    private func revokeSentence(for provider: Provider) -> String {
        if let whereToRevoke = provider.whereToRevoke {
            return "revoke it at \(whereToRevoke). That is the only thing that stops the spend."
        }
        return "revoke it where you issued it. That is the only thing that stops the spend."
    }

    private func nameBinding(_ key: BurnKey) -> Binding<String> {
        Binding(
            get: { nameDrafts[key.id] ?? key.name },
            set: { value in
                nameDrafts[key.id] = value
                // Committed as it is typed, but an emptied field keeps the last
                // real name rather than turning the row into a blank label.
                if !value.trimmingCharacters(in: .whitespaces).isEmpty {
                    model.rename(keyID: key.id, to: value)
                }
            }
        )
    }

    private func draftBinding(for provider: String) -> Binding<String> {
        Binding(
            get: { keyDrafts[provider] ?? "" },
            set: { keyDrafts[provider] = $0 }
        )
    }

    private func logBinding(_ keyID: String) -> Binding<String> {
        Binding(
            get: { logDrafts[keyID] ?? "" },
            set: { logDrafts[keyID] = $0 }
        )
    }

    private func logReading(keyID: String) {
        guard let cost = Double(logDrafts[keyID] ?? "") else { return }
        model.record(keyID: keyID, cost: max(0, cost))
        logDrafts[keyID] = ""
    }
}

/// A menu drawn as a quiet chip, so picking a provider or a category looks like
/// filling in a field rather than opening a system control.
struct MenuChip<Content: View>: View {
    let title: String
    var symbol: String? = nil
    var emphasised: Bool = false
    @ViewBuilder var content: Content

    @State private var hovering = false

    var body: some View {
        Menu {
            content
        } label: {
            HStack(spacing: DS.Space.xs) {
                if let symbol {
                    Image(systemName: symbol).font(.caption)
                }
                Text(title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(emphasised ? .secondary : .primary)
            .padding(.horizontal, DS.Space.sm)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.small - 1, style: .continuous)
                    .fill(Color(nsColor: .quaternaryLabelColor).opacity(hovering ? 0.32 : 0.20))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.small - 1, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor))
            )
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { hovering = $0 }
        .accessibilityLabel(Text("\(title). Choose from a list."))
    }
}

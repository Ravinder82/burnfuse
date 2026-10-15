import SwiftUI

/// Settings, built around two ideas: **you create your providers, and the key you
/// paste is the key you watch.**
///
/// There is no catalogue to read and nothing to classify. You name a provider —
/// whatever you call it, "OpenRouter", "fal", "my billing script" — paste the key
/// you already use, and say which pile its spend belongs in. Everything else is
/// worked out from what you gave: a key BurnFuse recognises is read for you, an
/// address you give is read for you, and anything else takes a number you type.
/// Every row says in plain words which of the three it is.
public struct SettingsView: View {
    @ObservedObject var model: AppModel
    var width: CGFloat? = 460
    var scrollable: Bool = true
    /// Overrides the path shown in the About card. The screenshot renderer
    /// points the model at a throwaway temp file, so it passes the canonical
    /// `~/.burnfuse/state.json` here instead of leaking that temp path.
    var displayStatePath: String? = nil
    /// Seeds the add-a-provider field for an offscreen render only, so a
    /// screenshot can show a pasted key being recognised. Never set in the
    /// running app.
    var previewAddKey: String = ""
    /// Seeds a provider's key field the same way.
    var previewKeyDrafts: [String: String] = [:]

    // Adding a provider.
    @State private var newName: String = ""
    @State private var newKey: String = ""
    @State private var pickedCategory: Category? = nil
    @State private var capDraft: String = "5"
    @State private var showAddress: Bool = false
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
            providersSection
            sensitivitySection
            alertsSection
            aboutSection
        }
        .padding(DS.Space.lg)
    }

    // MARK: - Your providers

    /// The providers you created, grouped by what they are for, and how to add
    /// another.
    ///
    /// The grouping is the answer to "which of these is which". A band says what
    /// the group is for, in that category's colour and with its own symbol, and
    /// every row leads with the tile of the name you gave it. Groups follow the
    /// categories' own order — coding first, "something else" last — and a
    /// category nobody has a provider in simply does not appear. The grouping is
    /// one panel; inside it every provider is its own card.
    private var providersSection: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                SectionHeader("Your providers",
                              subtitle: "Only the ones you add here. Paste the key you already use and BurnFuse watches that same key.") {
                    LinkButton(model.isRefreshing ? "Reading…" : "Refresh now",
                               enabled: !model.isRefreshing) {
                        Task { await model.refreshLive() }
                    }
                }

                if model.state.entries.isEmpty {
                    EmptyProviders()
                } else {
                    VStack(alignment: .leading, spacing: DS.Space.lg) {
                        ForEach(groupedKeys, id: \.category) { group in
                            VStack(alignment: .leading, spacing: DS.Space.sm) {
                                CategoryBand(category: group.category, keys: group.keys)
                                ForEach(group.keys) { key in
                                    KeyCard { keyRow(key) }
                                }
                            }
                        }
                    }
                }

                Divider()

                addProviderBlock
            }
        }
    }

    /// The providers that exist, in category order. Empty categories are dropped
    /// rather than shown as an empty band.
    private var groupedKeys: [(category: Category, keys: [BurnKey])] {
        Category.allCases.compactMap { category in
            let keys = model.state.entries.filter { $0.effectiveCategory == category }
            return keys.isEmpty ? nil : (category, keys)
        }
    }

    // MARK: Add a provider

    /// The whole add flow: name it, paste what you have, and BurnFuse works out
    /// the rest. The category is filled in from what the name or the key means,
    /// the line underneath says exactly what will happen, and the only field
    /// that grows the form is the address — for a provider that has no reader of
    /// its own.
    private var addProviderBlock: some View {
        let plan = providerPlan

        return VStack(alignment: .leading, spacing: DS.Space.sm) {
            Text("Add a provider").font(.subheadline.weight(.semibold))

            TextField("Name it — OpenRouter, fal, my billing script", text: $newName)
                .textFieldStyle(.roundedBorder)

            SecureField("Paste the key you already use", text: $newKey)
                .textFieldStyle(.roundedBorder)

            planNoteLine(plan)

            HStack(spacing: DS.Space.sm) {
                categoryMenu(plan: plan)

                Spacer(minLength: DS.Space.sm)

                HStack(spacing: DS.Space.xs) {
                    Text("Cap").font(.caption).foregroundStyle(.secondary)
                    TextField("5", text: $capDraft)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 58)
                    Text("$/hr").font(.caption).foregroundStyle(.secondary)
                }
            }

            addressDisclosure(plan)

            HStack(spacing: DS.Space.sm) {
                Spacer()
                PrimaryButton("Add provider", systemImage: "plus", enabled: canAdd) { addProvider() }
            }
        }
    }

    /// What BurnFuse makes of what is in the fields, as it is typed. This is the
    /// answer to "what will this provider do here", and it never asks the user to
    /// know a provider's internals to get it.
    @ViewBuilder
    private func planNoteLine(_ plan: Providers.ProviderPlan) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            note(plan.note, icon: plan.noteIcon, tone: AnyShapeStyle(.secondary))

            // The wrong *shape* of key for the reader this entry will use — a
            // normal OpenAI key where an Admin key is needed, say. Caught before
            // it costs a failed read.
            if let message = keyShapeWarning(plan) {
                note(message, icon: "exclamationmark.triangle.fill", tone: AnyShapeStyle(DS.Tone.watch))
            }
        }
    }

    private func keyShapeWarning(_ plan: Providers.ProviderPlan) -> String? {
        guard let key = Credentials.sanitize(newKey) else { return nil }
        let verdict = KeyShape.check(key, for: plan.kind)
        return verdict.severity == .warning ? verdict.message : nil
    }

    private func categoryMenu(plan: Providers.ProviderPlan) -> some View {
        MenuChip(title: plan.category.title, symbol: plan.category.symbol) {
            ForEach(Category.allCases) { category in
                Button("\(category.title) — \(category.blurb)") { pickedCategory = category }
            }
        }
        .help("The group this provider sits in. It changes nothing about how its spend is read.")
    }

    /// Where the number comes from, for a provider whose spend BurnFuse cannot
    /// read on its own. The field is the switch: filled in, the row reads itself;
    /// left alone, the row takes a number you type. No radio buttons, and the
    /// line above the fields says which of the two is about to happen.
    private func addressDisclosure(_ plan: Providers.ProviderPlan) -> some View {
        DisclosureGroup(isExpanded: $showAddress) {
            endpointFields
        } label: {
            Text(plan.wantsAddress ? "Read the number from an address" : "Use my own address instead")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
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
            note("Any address that returns a dollar figure works — your own script, a cloud billing export, a page behind a token. BurnFuse sends the key as Bearer under Authorization unless you name another header here. Leave this empty and the row takes a number you type instead.",
                 icon: nil, tone: AnyShapeStyle(.tertiary))
        }
    }

    // MARK: One watched provider

    private func keyRow(_ key: BurnKey) -> some View {
        let provider = Providers.provider(for: key.provider)
        let assessment = model.assessment(for: key)
        let tone = DS.Tone.forAssessment(overCap: assessment.overCap, spike: assessment.spike)
        let readFailed = model.lastReadFailed(key.id)
        // The same rule the watch list uses: a key nothing can read and nobody
        // has typed a number for has no figure at all, and "$0.00/hr" would be
        // the app inventing one.
        let hasNoFigure = (key.readings.isEmpty && !SpendSource.canReadLive(key))
            || (readFailed && key.readings.isEmpty)

        return VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(alignment: .top, spacing: DS.Space.sm) {
                ProviderTile(key: key, size: 28)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 1) {
                    // The name you gave it — the title of the row, and what
                    // trips, notifications and the watch list call this
                    // provider. Editable in place, the way a plain field is
                    // everywhere else on macOS.
                    TextField("Name", text: nameBinding(key))
                        .textFieldStyle(.plain)
                        .font(.callout.weight(.semibold))
                        .help("Click to rename. Trips and notifications call this provider by this name.")
                    // Which provider this is and how its number gets in, where
                    // the name does not already say it.
                    Text(key.readerPhrase)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: DS.Space.sm)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(hasNoFigure ? "—" : Fmt.perHour(key.lastReading))
                        .font(DS.Font.mono)
                        .foregroundStyle(hasNoFigure ? AnyShapeStyle(.secondary) : AnyShapeStyle(tone))
                    Text("cap \(Fmt.money(key.hourlyLimit))")
                        .font(DS.Font.monoSmall)
                        .foregroundStyle(.secondary)
                }

                // Removing a provider and revoking a key are different actions,
                // and the moment someone reaches for the first is the moment to
                // name the second.
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

                // Which group this provider sits in — the band it appears under.
                // Moving it is a filing decision and changes nothing about how
                // its spend is read.
                MenuChip(title: key.effectiveCategory.title,
                         symbol: key.effectiveCategory.symbol) {
                    ForEach(Category.allCases) { category in
                        Button(category.title) { model.setCategory(keyID: key.id, category: category) }
                    }
                }
                .help("The group this provider sits in. Moving it changes nothing about how its spend is read.")

                Spacer(minLength: DS.Space.sm)

                Toggle("Pause if it trips", isOn: Binding(
                    get: { key.autoKill },
                    set: { model.setAutoKill(keyID: key.id, enabled: $0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .font(.caption)
                .help("Stops BurnFuse reading this provider once it trips. It does not stop the provider billing.")
            }

            readingBlock(key, provider: provider)

            // The provider's own ceiling on this key, where it publishes one.
            // Not a BurnFuse cap and not a BurnFuse action — read from the
            // provider, and the only thing that stops a runaway without help.
            if let limit = model.keyLimits[key.id], !key.isManualRead {
                NoteText(limit.sentence,
                         icon: limit.isSpent ? "exclamationmark.octagon.fill" : "shield.lefthalf.filled",
                         tone: limit.isSpent ? AnyShapeStyle(DS.Tone.breach) : AnyShapeStyle(.secondary))
            }

            switchOffLine(key, provider: provider)
        }
    }

    /// The way from "this provider is hot" to "this key no longer exists" — the
    /// only action in the app that stops the money, so it is offered on the
    /// provider's own row and carries its explanation with it.
    ///
    /// Where the app cannot do it, the link is still here and the panel says why
    /// and where it *is* done: an honest answer beats a hidden one.
    @ViewBuilder
    private func switchOffLine(_ key: BurnKey, provider: Provider) -> some View {
        if model.switchOffKeyID == key.id {
            SwitchOffPanel(keyID: key.id, provider: provider, model: model)
        } else {
            LinkButton(Revoke.ability(for: provider.id).canSwitchOff
                       ? "Switch a key off at \(provider.label)…"
                       : "How to switch this key off…",
                       systemImage: "switch.2") {
                model.showSwitchOffPanel(keyID: key.id)
            }
        }
    }

    /// How this provider's number gets in — the one thing worth reading twice on
    /// this screen, so it always comes with the reason attached.
    @ViewBuilder
    private func readingBlock(_ key: BurnKey, provider: Provider) -> some View {
        if SpendSource.canReadLive(key) {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                if provider.id == "custom" {
                    endpointRow(key)
                }
                liveBlock(key, provider: provider)
            }
        } else {
            manualBlock(key, provider: provider)
        }
    }

    /// Your own endpoint's address, editable on the row itself. A provider with
    /// no address is one that can never be read, so this comes first.
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

    /// A provider whose spend is typed in. First class, not a failure: several of
    /// the biggest providers publish no cost endpoint at all, and a provider of
    /// your own may have nothing to read yet.
    private func manualBlock(_ key: BurnKey, provider: Provider) -> some View {
        let draft = logDrafts[key.id] ?? ""
        return VStack(alignment: .leading, spacing: DS.Space.xs) {
            note(manualHint(key, provider: provider), icon: "keyboard", tone: AnyShapeStyle(.tertiary))
            if let whereToRead = provider.whereToRead {
                note("Read it at \(whereToRead).", icon: "mappin.and.ellipse", tone: AnyShapeStyle(.tertiary))
            }

            // An address of your own is still on offer for a provider of your
            // own: filling this in is what turns "you type it" into "reads
            // itself", with the same key you already pasted.
            if provider.id == "custom" {
                endpointRow(key)
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
                if provider.canReadLive, provider.id != "custom" || key.source?.spendUrl != nil {
                    LinkButton("Read it automatically instead") {
                        model.setReadMode(keyID: key.id, mode: .auto)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    /// Why this row takes a typed number, in one line: the provider publishes
    /// nothing to read, or the person chose to type it. Never a mystery.
    private func manualHint(_ key: BurnKey, provider: Provider) -> String {
        if !provider.canReadLive { return provider.readHint }
        if key.isManualRead { return "You type this one's spend in yourself." }
        return provider.readHint
    }

    /// A provider BurnFuse reads itself. The key is stored once, here, and the
    /// row says which one it is — the two ends of it, never the whole thing.
    @ViewBuilder
    private func liveBlock(_ key: BurnKey, provider: Provider) -> some View {
        let resolved = Credentials.resolve(for: key)
        let stored = resolved.source == .stored
        let editing = replacing == key.id || !stored
        let draft = keyDrafts[key.id] ?? ""
        let verdict = KeyShape.check(draft, for: provider.id)
        let test = model.keyTests[key.id]

        VStack(alignment: .leading, spacing: DS.Space.xs) {
            if editing {
                HStack(spacing: DS.Space.sm) {
                    SecureField(provider.keyLabel, text: draftBinding(for: key.id))
                        .textFieldStyle(.roundedBorder)
                    SecondaryButton("Save", enabled: Credentials.sanitize(draft) != nil) {
                        model.storeCredential(draft, forKeyID: key.id)
                        keyDrafts[key.id] = ""
                        replacing = nil
                        Task { await model.refreshLive() }
                    }
                    SecondaryButton(test?.isTesting == true ? "Testing…" : "Test",
                                    enabled: test?.isTesting != true) {
                        Task { await model.testCredential(key.id, using: draft) }
                    }
                    if stored {
                        LinkButton("Cancel") { replacing = nil; keyDrafts[key.id] = "" }
                    }
                }
            } else {
                HStack(spacing: DS.Space.sm) {
                    if let masked = Credentials.masked(for: key) {
                        Label(masked, systemImage: "checkmark.seal.fill")
                            .font(DS.Font.monoSmall)
                            .foregroundStyle(DS.Tone.calm)
                            .help("The two ends of the key in use, so you can tell which one it is")
                    }
                    Spacer(minLength: DS.Space.sm)
                    LinkButton("Test") { Task { await model.testCredential(key.id) } }
                    LinkButton("Replace key") { replacing = key.id }
                    LinkButton("Remove", tint: DS.Tone.breach) {
                        model.storeCredential(nil, forKeyID: key.id)
                    }
                }
            }

            statusLine(key, provider: provider, test: test, verdict: verdict,
                       resolved: resolved, hasDraft: draft != "")
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
        resolved: Credentials.Resolution,
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
            } else if verdict.severity == .warning, let message = verdict.message, hasDraft {
                // The wrong kind of key, caught before it costs a failed read.
                note(message, icon: "exclamationmark.triangle.fill", tone: AnyShapeStyle(DS.Tone.watch))
            } else {
                sourceLine(key, provider: provider, resolved: resolved)
            }

            if hasDraft, resolved.source != .stored {
                note("Press Test to try the key in the field before saving it.", icon: "wand.and.stars", tone: AnyShapeStyle(.tertiary))
            }
        }
    }

    /// Where this row's key comes from, and what is being ignored to get there.
    ///
    /// This is the line that answers "I added my key and it still says the key
    /// is invalid": either the key in use is not the one you think it is, or
    /// something you forgot about is sitting in its place.
    @ViewBuilder
    private func sourceLine(_ key: BurnKey, provider: Provider, resolved: Credentials.Resolution) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            switch resolved.source {
            case .stored:
                if let read = model.lastMessageByKey[key.id] {
                    note(read.message,
                         icon: read.failed ? "exclamationmark.triangle.fill" : "arrow.clockwise",
                         tone: read.failed ? AnyShapeStyle(DS.Tone.watch) : AnyShapeStyle(.tertiary))
                    if read.failed, !key.isManualRead {
                        // The poll turned this key down, and this is where the
                        // person finds out. The other way to use the same key is
                        // offered right here rather than in another list.
                        LinkButton("Type this key's spend by hand instead") {
                            model.setReadMode(keyID: key.id, mode: .manual)
                        }
                    }
                } else {
                    note("BurnFuse reads this one for you, every minute.", icon: nil, tone: AnyShapeStyle(.tertiary))
                }
                environmentNote(key, provider: provider)

            case .environment(let variable):
                note("Nothing is saved here, so BurnFuse is using \(variable) from your environment\(maskedSuffix(key)). Paste a key here and that one will be used instead.",
                     icon: "terminal", tone: AnyShapeStyle(.tertiary))

            case .storedPlaceholder:
                note("The value saved here is the placeholder from a sample file, not a real key. Paste the key itself from your \(provider.label) console.",
                     icon: "exclamationmark.triangle.fill", tone: AnyShapeStyle(DS.Tone.watch))

            case .environmentPlaceholder(let variable):
                note("\(variable) in your environment is the placeholder from a sample file, not a real key — BurnFuse ignores it. Paste a real key here to read spend.",
                     icon: "exclamationmark.triangle.fill", tone: AnyShapeStyle(DS.Tone.watch))

            case .none:
                if provider.id == "custom" {
                    // Nothing to send is normal here: the address does the work,
                    // and a key only goes along if the person saved one.
                    note("Reading from the address above, with no key attached — add one if your address asks for it.",
                         icon: "arrow.clockwise", tone: AnyShapeStyle(.tertiary))
                } else {
                    note(provider.readHint, icon: nil, tone: AnyShapeStyle(.tertiary))
                    if let whereToGet = provider.whereToGet {
                        note(whereToGet, icon: "mappin.and.ellipse", tone: AnyShapeStyle(.tertiary))
                    }
                }
            }
        }
    }

    /// Says out loud what is being ignored, when a stored key is in use and the
    /// environment also has something for this provider. Silence here is how a
    /// forgotten export becomes a support thread.
    @ViewBuilder
    private func environmentNote(_ key: BurnKey, provider: Provider) -> some View {
        if let variable = Credentials.environmentVariable(for: key.provider),
           key.provider == provider.id,
           let value = Credentials.sanitize(ProcessInfo.processInfo.environment[variable] ?? "") {
            if KeyShape.looksLikeAPlaceholder(value) {
                note("\(variable) is set in your environment to a placeholder from a sample file — ignored. The key saved here is the one in use.",
                     icon: "terminal", tone: AnyShapeStyle(.tertiary))
            } else {
                note("\(variable) is set in your environment and is ignored: the key saved here is the one in use.",
                     icon: "terminal", tone: AnyShapeStyle(.tertiary))
            }
        }
    }

    private func maskedSuffix(_ key: BurnKey) -> String {
        guard let masked = Credentials.masked(for: key) else { return "" }
        return " (\(masked))"
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
            SectionHeader("About")
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

    // MARK: - Add-a-provider logic

    /// What adding will do, worked out as the fields are filled in. The
    /// decisions themselves live in `Providers.plan` so they can be tested
    /// without a window.
    private var providerPlan: Providers.ProviderPlan {
        Providers.plan(
            name: newName,
            key: newKey,
            category: pickedCategory,
            // An address counts while its fields are open. A section somebody
            // collapsed is not an instruction, and the line above says what will
            // happen without it.
            spendUrl: showAddress ? newSpendURL : "",
            jsonPath: showAddress ? newJSONPath : "",
            header: showAddress ? newHeader : "",
            measures: showAddress ? newMeasures : "rate",
            existingNames: model.state.entries.map(\.name)
        )
    }

    private var canAdd: Bool {
        !newName.trimmingCharacters(in: .whitespaces).isEmpty
            || Credentials.sanitize(newKey) != nil
            || (showAddress && !newSpendURL.trimmingCharacters(in: .whitespaces).isEmpty)
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

    private func addProvider() {
        let plan = providerPlan
        let cap = max(0.01, Double(capDraft) ?? 5)

        let added = model.addKey(
            name: plan.name,
            provider: plan.kind,
            cap: cap,
            category: pickedCategory,
            readMode: plan.readMode == .manual ? .manual : nil,
            spendUrl: plan.spendUrl,
            jsonPath: plan.jsonPath,
            header: plan.header,
            measures: plan.measures
        )

        // A pasted key is kept with the provider it was pasted for: it is what
        // reads an address the moment one exists, and it is what the ordinary
        // read for a recognised provider uses. The line above the fields said
        // what would happen with it, either way.
        if let typed = Credentials.sanitize(newKey) {
            model.storeCredential(typed, forKeyID: added.id)
        }

        newName = ""
        newKey = ""
        pickedCategory = nil
        capDraft = "5"
        showAddress = false
        newSpendURL = ""
        newJSONPath = ""
        newHeader = ""
        newMeasures = "rate"

        if plan.readMode == .auto { Task { await model.refreshLive() } }
    }

    // MARK: - Row helpers

    /// "revoke it at <page>" / "revoke it where you issued it", as a clause.
    private func revokeSentence(for provider: Provider) -> String {
        if Revoke.ability(for: provider.id).canSwitchOff {
            return "switch a \(provider.label) key off right here — the link at the foot of this row does it. That is the only thing that stops the spend."
        }
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

    private func draftBinding(for keyID: String) -> Binding<String> {
        Binding(
            get: { keyDrafts[keyID] ?? "" },
            set: { keyDrafts[keyID] = $0 }
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

/// One watched provider, on its own surface.
///
/// Rows separated by hairlines read as one long form — five providers that look
/// like five fields in the same box. A provider in Settings is a *thing*: a name,
/// a secret, a cap, a spend reading, and the sentences that belong to it alone
/// (including the switch-off panel, which opens inside its own card). So each one
/// gets a bordered surface with a step of space around it, and the eye can take
/// them one at a time. They are still filed under their category's band, because
/// the grouping is the answer to a different question.
///
/// The fill is the panel's own colour: the separation is a hairline and a
/// whisper of shadow, not a second colour anyone has to learn.
struct KeyCard<Content: View>: View {
    @ViewBuilder var content: Content

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DS.Radius.medium, style: .continuous)
    }

    var body: some View {
        content
            .padding(DS.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                shape
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(0.08), radius: 1.5, y: 1)
            )
            .overlay(shape.strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1))
    }
}

/// A menu drawn as a quiet chip, so picking a category looks like filling in a
/// field rather than opening a system control.
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

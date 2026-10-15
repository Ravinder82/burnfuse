import SwiftUI

/// The Overview screen of the unified window: what is burning, what is safe,
/// and the one thing you might need to do about it.
public struct OverviewView: View {
    @ObservedObject var model: AppModel
    var onAddKey: () -> Void = {}
    var onSeeTrips: (() -> Void)? = nil
    /// Called with a tripped key's id when the person asks to switch that key
    /// off at its provider. The window answers by opening Settings on it.
    var onSwitchOff: ((String) -> Void)? = nil

    public init(model: AppModel, onAddKey: @escaping () -> Void = {},
                onSeeTrips: (() -> Void)? = nil,
                onSwitchOff: ((String) -> Void)? = nil) {
        self.model = model
        self.onAddKey = onAddKey
        self.onSeeTrips = onSeeTrips
        self.onSwitchOff = onSwitchOff
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.lg) {
            if let incident = model.state.tripped.first {
                BreachBanner(
                    key: incident,
                    othersTripped: max(0, model.state.tripped.count - 1),
                    onArm: { model.arm(keyID: incident.id) },
                    onSeeTrips: onSeeTrips,
                    onSwitchOff: onSwitchOff.map { handler in { handler(incident.id) } }
                )
            }

            BurnHero(model: model)

            TokensCard(model: model)

            CategoryBreakdown(model: model)

            WatchedKeys(model: model, onAdd: onAddKey)

            StatusFooter(model: model)
        }
        .padding(DS.Space.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The headline: what every key is spending per hour right now, and the shape
/// of recent burn. One number, read in half a second.
public struct BurnHero: View {
    @ObservedObject var model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    /// Keys are set up, but nothing has been measured yet — every one of them is
    /// waiting for a number someone has to type. Saying "$0.00/hr" in the largest
    /// type on the screen would read as "nothing is burning", which is not
    /// something BurnFuse knows yet.
    private var nothingMeasured: Bool {
        !model.state.entries.isEmpty && model.state.entries.allSatisfy { $0.readings.isEmpty }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            DS.eyebrow("Burning now")

            HStack(alignment: .firstTextBaseline, spacing: DS.Space.sm) {
                Text(Fmt.perHour(model.state.totalBurn))
                    .font(DS.Font.hero)
                    .foregroundStyle(model.state.hasBreach
                                     ? AnyShapeStyle(DS.Tone.breach)
                                     : (nothingMeasured ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary)))
                    .contentTransition(.numericText())

                Spacer()

                if !model.state.entries.isEmpty {
                    Text("cap \(Fmt.money(model.state.totalCap))/hr")
                        .font(DS.Font.monoSmall)
                        .foregroundStyle(.secondary)
                }
            }

            Sparkline(
                values: BurnEngine.combinedSeries(model.state),
                tone: model.state.hasBreach ? DS.Tone.breach : DS.Tone.calm,
                lineWidth: 2
            )
            .frame(height: 56)
            .opacity(model.state.entries.isEmpty ? 0 : 1)

            Text(model.state.entries.isEmpty
                 ? "Add a key to start watching your burn."
                 : (nothingMeasured
                    ? "No readings yet — nothing has been measured."
                    : "Trend across your last readings."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// What the keys used in tokens today, from the providers that report it.
///
/// The dollar figure says how fast the money is going. This says *why*: models
/// are priced per token and differ by orders of magnitude, so "this key is
/// burning $9.90 an hour" becomes something a person can act on the moment it
/// can be read next to "it pushed four million tokens".
///
/// Only some providers publish counts, so the card names the ones that answered
/// and says plainly when a provider cannot answer at all. Nothing is estimated:
/// a provider that does not report tokens shows none, and a number from
/// yesterday is never shown under today's heading.
public struct TokensCard: View {
    @ObservedObject var model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    private struct Reported {
        var key: BurnKey
        var use: TokenUse
    }

    /// Today's readings only. A figure whose window is another day is not shown
    /// at all — it would be a number under the wrong heading.
    private var reported: [Reported] {
        model.state.entries.compactMap { key in
            guard !key.isManualRead, let use = key.tokenUse, use.isCurrent() else { return nil }
            return Reported(key: key, use: use)
        }
    }

    private var totals: (input: Int, output: Int, cached: Int?) {
        var input = 0, output = 0, cached = 0
        var sawCache = false
        for reading in reported {
            input += reading.use.input
            output += reading.use.output
            if let value = reading.use.cachedInput {
                cached += value
                sawCache = true
            }
        }
        return (input, output, sawCache ? cached : nil)
    }

    /// The keys whose provider counts tokens but has not answered yet, so the
    /// card can say it is waiting instead of showing a zero.
    private var waiting: [String] {
        let answered = Set(reported.map { $0.key.provider })
        return ordered(Set(model.state.entries
            .filter { !$0.isManualRead && SpendSource.reportsTokens($0.provider) }
            .map { $0.provider }
            .filter { !answered.contains($0) }))
    }

    /// Watched providers that publish no token counts at all.
    private var silent: [String] {
        ordered(Set(model.state.entries
            .filter { !$0.isManualRead && !SpendSource.reportsTokens($0.provider) }
            .map { $0.provider }))
    }

    private var providerOrder: [String] { Providers.all.map { $0.id } }

    private func ordered(_ ids: Set<String>) -> [String] {
        ids.sorted { (providerOrder.firstIndex(of: $0) ?? .max) < (providerOrder.firstIndex(of: $1) ?? .max) }
    }

    private func list(_ ids: [String]) -> String {
        let names = ids.map { Providers.label(for: $0) }
        switch names.count {
        case 0: return ""
        case 1: return names[0]
        case 2: return "\(names[0]) and \(names[1])"
        default: return names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
        }
    }

    /// Today's spend on the keys whose tokens we have, for the one derived
    /// figure on the card — an average over whatever mix of models actually ran,
    /// which is exactly why it is written as an average and not a price.
    private var spendWithTokens: Double {
        reported.compactMap { $0.key.lastCumulative }.reduce(0, +)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            SectionHeader("Tokens") {
                Text(newestRead == nil ? "Today" : "Today · read \(newestRead!.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help("The window the providers bucket by: their day, midnight to midnight UTC.")
            }

            Card(padding: DS.Space.md) {
                VStack(alignment: .leading, spacing: DS.Space.sm) {
                    if reported.isEmpty {
                        Text(waiting.isEmpty
                             ? "No key here reads from a provider that counts tokens."
                             : "Nothing read from \(list(waiting)) yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        HStack(alignment: .top, spacing: DS.Space.xxl) {
                            metric("In", Fmt.tokens(totals.input))
                            metric("Out", Fmt.tokens(totals.output))
                            if let cached = totals.cached {
                                metric("Cached", Fmt.tokens(cached))
                            }
                            Spacer(minLength: 0)
                        }

                        if reported.contains(where: { $0.use.cachedInput != nil }) {
                            Text("In counts every input token, including the ones served from the cache; Cached is that part of it, not an addition.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if spendWithTokens > 0 {
                            Text("About \(Fmt.perMillionTokens(spend: spendWithTokens, tokens: totals.input + totals.output)) — today's \(Fmt.money(spendWithTokens)) on the keys these counts came from.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Text(footnote)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var newestRead: Date? {
        reported.map { $0.use.date }.max()
    }

    /// Who fed these numbers, and who never could — in that order, in one
    /// sentence each, so a missing count is never a mystery.
    private var footnote: String {
        var parts: [String] = []
        if reported.isEmpty {
            if !silent.isEmpty { parts.append(silentNote) }
            return parts.joined(separator: " ")
        }
        let names = ordered(Set(reported.map { $0.key.provider }))
        parts.append("From \(list(names)).")
        parts.append("Counts are for the provider's own day — midnight to midnight UTC, the same hours its dollars cover.")
        if !silent.isEmpty { parts.append(silentNote) }
        return parts.joined(separator: " ")
    }

    private var silentNote: String {
        if silent == ["openrouter"] {
            return "OpenRouter reports credits, not tokens, so its keys have none."
        }
        if silent.contains("openrouter") {
            return "OpenRouter reports credits rather than tokens, and the others publish no counts."
        }
        return "No token counts are published for \(list(silent))."
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            DS.eyebrow(label)
            Text(value)
                .font(DS.Font.metric)
                .contentTransition(.numericText())
        }
    }
}

/// The watch list: every key, its burn, its cap, and one action.
public struct WatchedKeys: View {
    @ObservedObject var model: AppModel
    var onAdd: () -> Void = {}

    public init(model: AppModel, onAdd: @escaping () -> Void = {}) {
        self.model = model
        self.onAdd = onAdd
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            SectionHeader("Watched keys") {
                LinkButton("Add", systemImage: "plus", action: onAdd)
            }

            if model.state.entries.isEmpty {
                EmptyProviders()
            } else {
                VStack(spacing: DS.Space.sm) {
                    ForEach(model.state.entries) { key in
                        Card(padding: DS.Space.md) {
                            KeyRow(
                                key: key,
                                assessment: model.assessment(for: key),
                                readFailed: model.lastReadFailed(key.id),
                                onTrip: { model.trip(keyID: key.id) },
                                onArm: { model.arm(keyID: key.id) },
                                onOpen: onAdd
                            )
                        }
                    }
                }
            }
        }
    }
}

/// The status line at the foot of the Overview: when it last checked, and the
/// fleet-wide actions.
public struct StatusFooter: View {
    @ObservedObject var model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        HStack(spacing: DS.Space.sm) {
            Circle()
                .fill(model.state.hasBreach ? DS.Tone.breach : DS.Tone.calm)
                .frame(width: 6, height: 6)

            Text("Checked \(RelativeTime.short(model.lastRefresh))")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let message = model.lastReadMessage, model.isRefreshing == false {
                Text("·").foregroundStyle(.tertiary)
                Text(message.split(separator: "\n").first.map(String.init) ?? "")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            if model.state.hasBreach {
                LinkButton("Re-arm all") { model.armAll() }
            }

            LinkButton("Trip all", tint: DS.Tone.breach) { model.tripAll() }
                .opacity(canCutAll ? 1 : 0.4)
                .disabled(!canCutAll)
        }
    }

    private var canCutAll: Bool {
        !model.state.entries.isEmpty && model.state.tripped.count != model.state.entries.count
    }
}

/// Empty state — tells you exactly what to do next, nothing more.
public struct EmptyProviders: View {
    public init() {}

    public var body: some View {
        VStack(spacing: DS.Space.sm) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("Nothing watched yet").font(.subheadline.weight(.medium))
            Text("Add a provider — paste a key you already use, or name one and type what it spends.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Space.xl)
    }
}

/// Shown at the top of the Overview when the breaker has tripped. States plainly
/// what happened, what BurnFuse actually did about it, and the one action that
/// ends the spend — which is not an action BurnFuse can take.
public struct BreachBanner: View {
    let key: BurnKey
    let othersTripped: Int
    let onArm: () -> Void
    let onSeeTrips: (() -> Void)?
    /// Present only when the provider is one BurnFuse can actually act on.
    let onSwitchOff: (() -> Void)?

    public init(
        key: BurnKey,
        othersTripped: Int = 0,
        onArm: @escaping () -> Void,
        onSeeTrips: (() -> Void)? = nil,
        onSwitchOff: (() -> Void)? = nil
    ) {
        self.key = key
        self.othersTripped = othersTripped
        self.onArm = onArm
        self.onSeeTrips = onSeeTrips
        self.onSwitchOff = onSwitchOff
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(spacing: DS.Space.sm) {
                Image(systemName: "exclamationmark.octagon.fill")
                    .foregroundStyle(DS.Tone.breach)
                Text("Breaker tripped").font(.subheadline.weight(.semibold))
                Spacer()
            }
            Text("\(key.name) hit \(Fmt.perHour(key.lastReading)) against a \(Fmt.money(key.hourlyLimit)) cap.")
                .font(.caption.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)

            // What BurnFuse did, then what would actually end the spend. Watching
            // is not cutting: the app can stop reading a key, but only the
            // provider can stop billing for it — and where the app holds a
            // credential the provider accepts, it can ask for exactly that.
            Text(key.armed
                 ? "BurnFuse is still reading it, so you can watch it come down. \(endTheSpend)"
                 : "BurnFuse has stopped reading it. \(endTheSpend)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if othersTripped > 0 {
                // Naming one tripped key and staying quiet about the rest is how
                // a second runaway goes unnoticed.
                Text(othersTripped == 1
                     ? "One other key has tripped as well."
                     : "\(othersTripped) other keys have tripped as well.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: DS.Space.sm) {
                PrimaryButton("Re-arm", tint: DS.accent, action: onArm)
                if let onSwitchOff {
                    SecondaryButton("Switch a key off at \(Providers.label(for: key.provider))…",
                                    systemImage: "switch.2",
                                    tint: DS.Tone.breach,
                                    action: onSwitchOff)
                }
                if let onSeeTrips {
                    SecondaryButton("All trips", action: onSeeTrips)
                }
            }
        }
        .padding(DS.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Tone.breach.opacity(0.10))
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityElement(children: .contain)
    }

    /// The sentence that says how the money actually stops — and changes only
    /// when the answer does.
    private var endTheSpend: String {
        if Revoke.ability(for: key.provider).canSwitchOff {
            return "Only \(Providers.label(for: key.provider)) can stop the billing, and BurnFuse can ask it to: switch the key off and it cannot bill again."
        }
        return Providers.revokeHint(for: key.provider)
    }
}
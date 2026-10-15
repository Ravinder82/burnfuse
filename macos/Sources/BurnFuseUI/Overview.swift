import SwiftUI

/// The Overview screen of the unified window: what is burning, what is safe,
/// and the one thing you might need to do about it.
public struct OverviewView: View {
    @ObservedObject var model: AppModel
    var onAddKey: () -> Void = {}
    var onSeeTrips: (() -> Void)? = nil

    public init(model: AppModel, onAddKey: @escaping () -> Void = {}, onSeeTrips: (() -> Void)? = nil) {
        self.model = model
        self.onAddKey = onAddKey
        self.onSeeTrips = onSeeTrips
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.lg) {
            if let incident = model.state.tripped.first {
                BreachBanner(
                    key: incident,
                    othersTripped: max(0, model.state.tripped.count - 1),
                    onArm: { model.arm(keyID: incident.id) },
                    onSeeTrips: onSeeTrips
                )
            }

            BurnHero(model: model)

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

    public var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            DS.eyebrow("Burning now")

            HStack(alignment: .firstTextBaseline, spacing: DS.Space.sm) {
                Text(Fmt.perHour(model.state.totalBurn))
                    .font(DS.Font.hero)
                    .foregroundStyle(model.state.hasBreach ? DS.Tone.breach : .primary)
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
                 : "Trend across your last readings.")
                .font(.caption)
                .foregroundStyle(.secondary)
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
                EmptyKeys()
            } else {
                VStack(spacing: DS.Space.sm) {
                    ForEach(model.state.entries) { key in
                        Card(padding: DS.Space.md) {
                            KeyRow(
                                key: key,
                                assessment: model.assessment(for: key),
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
public struct EmptyKeys: View {
    public init() {}

    public var body: some View {
        VStack(spacing: DS.Space.sm) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("No keys watched yet").font(.subheadline.weight(.medium))
            Text("Add a key to start watching its burn.")
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

    public init(
        key: BurnKey,
        othersTripped: Int = 0,
        onArm: @escaping () -> Void,
        onSeeTrips: (() -> Void)? = nil
    ) {
        self.key = key
        self.othersTripped = othersTripped
        self.onArm = onArm
        self.onSeeTrips = onSeeTrips
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
            // is not cutting: the app can stop reading a key, but the provider is
            // the only party that can stop billing for it, so it says where.
            Text(key.armed
                 ? "BurnFuse is still reading it, so you can watch it come down. \(Providers.revokeHint(for: key.provider))"
                 : "BurnFuse has stopped reading it. \(Providers.revokeHint(for: key.provider))")
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
}
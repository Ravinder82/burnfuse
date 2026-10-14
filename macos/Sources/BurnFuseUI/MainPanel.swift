import SwiftUI

/// The menu-bar panel. One screen, no tabs, no nesting: what is burning, what
/// is safe, and the one thing you might need to do about it.
public struct MainPanel: View {
    @ObservedObject var model: AppModel
    var width: CGFloat = 340
    var scrollable: Bool = true
    var onOpenSettings: () -> Void = {}
    var onQuit: () -> Void = {}

    public init(
        model: AppModel,
        width: CGFloat = 340,
        scrollable: Bool = true,
        onOpenSettings: @escaping () -> Void = {},
        onQuit: @escaping () -> Void = {}
    ) {
        self.model = model
        self.width = width
        self.scrollable = scrollable
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            if let incident = model.state.tripped.first {
                BreachBanner(key: incident, onArm: { model.arm(keyID: incident.id) },
                             onReview: { onOpenSettings() })
            }

            if scrollable {
                ScrollView {
                    panelContent
                }
                .frame(maxHeight: 384)
            } else {
                panelContent
            }

            Divider()
            footer
        }
        .frame(width: width)
        .background(.regularMaterial)
    }

    private var panelContent: some View {
        VStack(alignment: .leading, spacing: DS.Space.lg) {
            hero
            keyList
        }
        .padding(DS.Space.lg)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: DS.Space.sm) {
            BrandMark(size: 20)

            Text("burnfuse").font(.headline)

            Spacer(minLength: DS.Space.sm)

            StatusChip(
                text: model.statusSummary,
                systemImage: model.state.hasBreach ? "exclamationmark.octagon.fill" : "checkmark.shield.fill",
                tone: model.state.hasBreach ? DS.Tone.breach : DS.Tone.calm
            )

            IconButton("gearshape", help: "Settings") { onOpenSettings() }
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.vertical, DS.Space.md)
    }

    // MARK: Hero

    private var hero: some View {
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

            Sparkline(values: BurnEngine.combinedSeries(model.state),
                      tone: model.state.hasBreach ? DS.Tone.breach : DS.Tone.calm,
                      lineWidth: 2)
                .frame(height: 44)
                .opacity(model.state.entries.isEmpty ? 0 : 1)

            Text(model.state.entries.isEmpty
                 ? "Add a key to start watching your burn."
                 : "Trend across your last readings.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Keys

    private var keyList: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            SectionHeader("Watched keys") {
                LinkButton("Add", systemImage: "plus") { onOpenSettings() }
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
                                compact: true,
                                onTrip: { model.trip(keyID: key.id) },
                                onArm: { model.arm(keyID: key.id) },
                                onOpen: { onOpenSettings() }
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: DS.Space.sm) {
            Circle()
                .fill(model.state.hasBreach ? DS.Tone.breach : DS.Tone.calm)
                .frame(width: 6, height: 6)
            Text("Checked \(RelativeTime.short(model.lastRefresh))")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()

            if model.state.hasBreach {
                LinkButton("Re-arm all") { model.armAll() }
                Text("·").foregroundStyle(.tertiary)
            }

            LinkButton("Cut all", tint: DS.Tone.breach) { model.tripAll() }
                .opacity(canCutAll ? 1 : 0.4)
                .disabled(!canCutAll)

            Text("·").foregroundStyle(.tertiary)

            LinkButton("Quit", tint: .secondary) { onQuit() }
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.vertical, DS.Space.sm)
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
            Text("Run `burnfuse scan` in your project, or add a key in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Space.xl)
    }
}

/// Shown at the top of the panel when the breaker has tripped. States plainly
/// what happened, what it averted, and the one recovery action.
public struct BreachBanner: View {
    let key: BurnKey
    let onArm: () -> Void
    let onReview: () -> Void

    public init(key: BurnKey, onArm: @escaping () -> Void, onReview: @escaping () -> Void) {
        self.key = key
        self.onArm = onArm
        self.onReview = onReview
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(spacing: DS.Space.sm) {
                Image(systemName: "exclamationmark.octagon.fill")
                    .foregroundStyle(DS.Tone.breach)
                Text("Breaker tripped").font(.subheadline.weight(.semibold))
                Spacer()
            }
            Text("\(key.name) hit \(Fmt.perHour(key.lastReading)) against a \(Fmt.money(key.hourlyLimit)) cap. It is paused so it cannot keep draining.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: DS.Space.sm) {
                PrimaryButton("Re-arm", tint: DS.accent, action: onArm)
                SecondaryButton("Review", action: onReview)
            }
        }
        .padding(DS.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Tone.breach.opacity(0.10))
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityElement(children: .contain)
    }
}
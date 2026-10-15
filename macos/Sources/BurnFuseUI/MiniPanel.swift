import SwiftUI

/// The menu-bar panel — a miniature of the app.
///
/// Clicking the menu-bar item opens this, not a menu: the same live burn, the
/// same watch list, and the same one action, at a size you can keep an eye on
/// without leaving what you were doing. "Open BurnFuse" hands off to the full
/// window when you want the whole picture.
public struct MiniPanel: View {
    @ObservedObject var model: AppModel
    var onOpen: (AppSection) -> Void = { _ in }
    var onQuit: () -> Void = {}

    public init(
        model: AppModel,
        onOpen: @escaping (AppSection) -> Void = { _ in },
        onQuit: @escaping () -> Void = {}
    ) {
        self.model = model
        self.onOpen = onOpen
        self.onQuit = onQuit
    }

    private var tone: Color {
        model.state.hasBreach ? DS.Tone.breach : DS.Tone.calm
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            header
            hero

            if model.state.entries.isEmpty {
                EmptyKeys()
            } else {
                Sparkline(
                    values: BurnEngine.combinedSeries(model.state),
                    tone: tone,
                    lineWidth: 1.6
                )
                .frame(height: 34)

                keyList
            }

            Divider().opacity(0.6)
            actions
            Divider().opacity(0.6)
            footer
        }
        .padding(DS.Space.md)
        .frame(width: 296)
        .environment(\.glassPanels, true)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DS.Space.sm) {
            BrandMark(size: 15)
            Text("burnfuse")
                .font(.subheadline.weight(.semibold))

            Spacer(minLength: DS.Space.sm)

            if model.isRefreshing {
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.7)
            } else {
                Text(model.statusSummary)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(model.state.hasBreach ? DS.Tone.breach : .secondary)
            }

            IconButton("arrow.up.right.square", help: "Open BurnFuse") { onOpen(.overview) }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            DS.eyebrow("Burning now")
            HStack(alignment: .firstTextBaseline, spacing: DS.Space.sm) {
                Text(Fmt.perHour(model.state.totalBurn))
                    .font(DS.Font.metric)
                    .foregroundStyle(tone)
                    .contentTransition(.numericText())

                Spacer(minLength: DS.Space.sm)

                if !model.state.entries.isEmpty {
                    Text("cap \(Fmt.money(model.state.totalCap))/hr")
                        .font(DS.Font.monoSmall)
                        .foregroundStyle(.secondary)
                }
            }

            if let incident = model.state.tripped.first {
                let more = model.state.tripped.count - 1
                Text(more > 0
                     ? "\(incident.name) and \(more) more tripped — revoke the keys to stop the spend."
                     : "\(incident.name) tripped — revoke its key to stop the spend.")
                    .font(.caption2)
                    .foregroundStyle(DS.Tone.breach)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Watch list

    private var keyList: some View {
        let entries = model.state.entries
        let shown = Array(entries.prefix(4))
        return VStack(alignment: .leading, spacing: DS.Space.sm) {
            ForEach(shown) { key in
                MiniKeyRow(
                    key: key,
                    assessment: model.assessment(for: key),
                    onTrip: { model.trip(keyID: key.id) },
                    onArm: { model.arm(keyID: key.id) }
                )
            }
            if entries.count > shown.count {
                Button {
                    onOpen(.overview)
                } label: {
                    Text("+\(entries.count - shown.count) more")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Actions

    private var actions: some View {
        HStack(spacing: DS.Space.sm) {
            if model.state.hasBreach {
                PrimaryButton("Re-arm all", tint: DS.Tone.calm) { model.armAll() }
            }
            Spacer(minLength: DS.Space.sm)
            SecondaryButton("Trip all", tint: DS.Tone.breach) { model.tripAll() }
                .opacity(canCutAll ? 1 : 0.4)
                .disabled(!canCutAll)
        }
    }

    private var canCutAll: Bool {
        !model.state.entries.isEmpty && model.state.tripped.count != model.state.entries.count
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: DS.Space.md) {
            LinkButton("Open BurnFuse") { onOpen(.overview) }
            LinkButton("Insights") { onOpen(.insights) }
            LinkButton("Settings") { onOpen(.settings) }

            Spacer(minLength: DS.Space.sm)

            IconButton("power", help: "Quit BurnFuse", action: onQuit)
        }
    }
}

/// A compact key line for the panel: name, burn, and a hairline meter. Tapping
/// it hands off to the full window.
struct MiniKeyRow: View {
    let key: BurnKey
    let assessment: BurnEngine.Assessment
    let onTrip: () -> Void
    let onArm: () -> Void

    private var tone: Color {
        DS.Tone.forAssessment(overCap: assessment.overCap, spike: assessment.spike)
    }

    private var symbol: String {
        if key.isTripped { return "exclamationmark.octagon.fill" }
        if !key.armed { return "pause.circle.fill" }
        if assessment.overCap { return "flame.fill" }
        if assessment.spike { return "waveform.path.ecg" }
        return "checkmark.shield.fill"
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            HStack(spacing: DS.Space.sm) {
                Image(systemName: Providers.provider(for: key.provider).symbol)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 14)

                Text(key.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)

                Spacer(minLength: DS.Space.xs)

                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tone)

                Text(Fmt.perHour(key.lastReading))
                    .font(DS.Font.monoSmall)
                    .foregroundStyle(tone)

                if key.isTripped {
                    IconButton("arrow.clockwise", tint: DS.Tone.calm, help: "Re-arm", action: onArm)
                } else {
                    IconButton("power", tint: DS.Tone.breach, help: "Trip this key", action: onTrip)
                }
            }

            BurnMeter(fill: key.capFill, tone: tone)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(key.name), \(Fmt.perHour(key.lastReading)), cap \(Fmt.money(key.hourlyLimit))")
    }
}
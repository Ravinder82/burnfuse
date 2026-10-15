import SwiftUI

/// A single key in the watch list. Reads left to right: what it is, how hot it
/// is, and whether it needs you.
public struct KeyRow: View {
    let key: BurnKey
    let assessment: BurnEngine.Assessment
    let onTrip: () -> Void
    let onArm: () -> Void
    let onOpen: () -> Void
    var compact: Bool = false

    private var tone: Color { DS.Tone.forAssessment(overCap: assessment.overCap, spike: assessment.spike) }

    private var stateLabel: String {
        if key.isTripped { return "Tripped" }
        if !key.armed { return "Paused" }
        if assessment.overCap { return "Over cap" }
        if assessment.spike { return "Spiking" }
        return "Armed"
    }

    /// Plain-language signal, shown only when something is worth noticing.
    /// No statistics in the interface — just how far from normal this is.
    private var signal: String? {
        guard assessment.samples > 0, assessment.baseline > 0 else { return nil }
        if assessment.overCap { return "over your cap" }
        if assessment.spike {
            let multiple = assessment.current / assessment.baseline
            return String(format: "%.1f× its usual rate", multiple)
        }
        return nil
    }

    private var stateSymbol: String {
        if key.isTripped { return "exclamationmark.octagon.fill" }
        if !key.armed { return "pause.circle.fill" }
        if assessment.overCap { return "flame.fill" }
        if assessment.spike { return "waveform.path.ecg" }
        return "checkmark.shield.fill"
    }

    public init(
        key: BurnKey,
        assessment: BurnEngine.Assessment,
        compact: Bool = false,
        onTrip: @escaping () -> Void,
        onArm: @escaping () -> Void,
        onOpen: @escaping () -> Void
    ) {
        self.key = key
        self.assessment = assessment
        self.compact = compact
        self.onTrip = onTrip
        self.onArm = onArm
        self.onOpen = onOpen
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(alignment: .firstTextBaseline, spacing: DS.Space.sm) {
                Image(systemName: Providers.provider(for: key.provider).symbol)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(key.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                    if !compact {
                        Text(Providers.label(for: key.provider))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: DS.Space.sm)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(Fmt.perHour(key.lastReading))
                        .font(DS.Font.mono)
                        .foregroundStyle(tone)
                    Text("cap \(Fmt.money(key.hourlyLimit))")
                        .font(DS.Font.monoSmall)
                        .foregroundStyle(.secondary)
                }
            }

            BurnMeter(fill: key.capFill, tone: tone)

            HStack(spacing: DS.Space.sm) {
                StatusChip(text: stateLabel, systemImage: stateSymbol, tone: tone)

                if let signal {
                    Text(signal)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: DS.Space.xs)

                if key.isTripped {
                    SecondaryButton("Re-arm", tint: DS.Tone.calm, action: onArm)
                } else {
                    // Named for what it does to BurnFuse — mark the key and stop
                    // reading it. "Cut power" promised something the app cannot
                    // do, which is stop the provider billing.
                    SecondaryButton("Trip now", tint: DS.Tone.breach, action: onTrip)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(key.name), \(stateLabel), burning \(Fmt.perHour(key.lastReading)), cap \(Fmt.money(key.hourlyLimit))")
    }
}
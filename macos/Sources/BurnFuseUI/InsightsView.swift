import SwiftUI

/// The "what did this actually do for me" screen. One number that matters,
/// the honest risk framing, and a plain log of what tripped and when.
public struct InsightsView: View {
    @ObservedObject var model: AppModel
    var width: CGFloat? = 360
    var scrollable: Bool = true

    public init(model: AppModel, width: CGFloat? = 360, scrollable: Bool = true) {
        self.model = model
        self.width = width
        self.scrollable = scrollable
    }

    private var averted: Double { BurnEngine.totalAverted(model.state) }
    private var atRisk: Double { model.state.totalBurn * BurnEngine.exposureHours }

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
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: DS.Space.lg) {
            headline
            riskCard
            incidentLog
        }
        .padding(DS.Space.lg)
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            DS.eyebrow("Averted so far")
            Text(Fmt.money(averted, digits: 0))
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .foregroundStyle(averted > 0 ? DS.Tone.calm : .primary)
                .contentTransition(.numericText())
            Text(averted > 0
                 ? "Estimated spend the breaker stopped before it landed on your card."
                 : "Once a key trips, the spend it stopped shows up here.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var riskCard: some View {
        Card {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                SectionHeader("If nothing was watching", subtitle: "Your current burn, left unchecked")
                HStack(spacing: DS.Space.lg) {
                    projection("4 hours", model.state.totalBurn * 4)
                    Divider().frame(height: 34)
                    projection("8 hours", model.state.totalBurn * 8)
                    Divider().frame(height: 34)
                    projection("24 hours", model.state.totalBurn * 24)
                }
                Text("Billing emails often arrive hours later. This is what an unattended loop looks like at today's rate.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func projection(_ label: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(Fmt.money(value, digits: 0))
                .font(DS.Font.metric)
                .foregroundStyle(value > 0 ? DS.Tone.watch : .primary)
        }
    }

    private var incidentLog: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            SectionHeader("Trips", subtitle: "Every time a breaker fired") {
                if !model.state.incidents.isEmpty {
                    LinkButton("Clear") { model.clearIncidents() }
                }
            }

            if model.state.incidents.isEmpty {
                Card {
                    VStack(alignment: .leading, spacing: DS.Space.xs) {
                        Label("Nothing has tripped", systemImage: "checkmark.seal.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(DS.Tone.calm)
                        Text("Your keys are all inside their caps and normal range.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                VStack(spacing: DS.Space.sm) {
                    ForEach(model.state.incidents.prefix(20)) { incident in
                        Card(padding: DS.Space.md) {
                            incidentRow(incident)
                        }
                    }
                }
            }
        }
    }

    private func incidentRow(_ incident: Incident) -> some View {
        HStack(alignment: .top, spacing: DS.Space.sm) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 11))
                .foregroundStyle(DS.Tone.breach)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(incident.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text("\(Fmt.perHour(incident.reading)) vs \(Fmt.money(incident.hourlyLimit)) cap · \(incident.reason)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(RelativeTime.short(incident.date))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: DS.Space.sm)

            VStack(alignment: .trailing, spacing: 1) {
                Text(Fmt.money(BurnEngine.averted(incident), digits: 0))
                    .font(DS.Font.mono)
                    .foregroundStyle(DS.Tone.calm)
                Text("averted").font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }
}
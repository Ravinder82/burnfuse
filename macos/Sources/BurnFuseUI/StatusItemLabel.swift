import SwiftUI

/// The menu-bar item: a solid colour block whose tint tracks how hot the burn
/// is, with the live number inside. Green means settled, amber means climbing,
/// red means the breaker has tripped. One glance, no reading required.
///
/// It lives in the UI module (not the app target) so the screenshot renderer can
/// capture the real item rather than approximate it.
public struct StatusItemLabel: View {
    @ObservedObject var model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    private var breached: Bool { model.state.hasBreach }
    private var empty: Bool { model.state.entries.isEmpty }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: breached ? "flame.fill" : "flame")
                .font(.system(size: 10.5, weight: .semibold))
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 2.5)
        .background(
            Capsule(style: .continuous)
                .fill(blockColour)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
        )
        .accessibilityLabel(accessibilityText)
    }

    private var label: String {
        if breached { return "\(model.state.tripped.count)" }
        if empty { return "idle" }
        return shortMoney
    }

    private var shortMoney: String {
        let total = model.state.totalBurn
        if total <= 0 { return "$0" }
        if total < 10 { return String(format: "$%.2f", total) }
        return String(format: "$%.0f", total)
    }

    /// The colour block. Red when tripped, grey when idle, and otherwise a
    /// continuous green → amber → orange ramp as burn approaches the cap — so
    /// the colour carries the number and the number carries the colour.
    private var blockColour: Color {
        if breached { return Color(red: 0.85, green: 0.16, blue: 0.18) }
        if empty { return Color(red: 0.42, green: 0.45, blue: 0.50) }
        return StatusItemLabel.blockColour(forFraction: model.burnFraction)
    }

    /// The colour ramp, exposed so the renderer and tests share one definition.
    /// Eased so ordinary burn already reads a touch warm and the last stretch
    /// climbs quickly — the hotter it gets, the faster it turns.
    public static func blockColour(forFraction fraction: Double) -> Color {
        let f = min(max(fraction, 0), 1)
        let hue = 0.34 - 0.30 * pow(f, 0.5)   // 0.34 (green) → 0.04 (red-orange)
        return Color(hue: hue, saturation: 0.80, brightness: 0.92)
    }

    private var accessibilityText: String {
        if breached {
            return "BurnFuse, \(model.state.tripped.count) keys tripped"
        }
        if empty {
            return "BurnFuse, no keys watched"
        }
        return "BurnFuse, \(Fmt.perHour(model.state.totalBurn)) burning now, \(Int(model.burnFraction * 100)) percent of cap"
    }
}
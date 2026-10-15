import SwiftUI

/// Lays chips out left to right, wrapping onto a new line when the width runs
/// out. An `HStack` would squash them or overflow the window; this keeps every
/// chip exactly the size of its own text.
public struct FlowLayout: Layout {
    var spacing: CGFloat = DS.Space.sm

    public init(spacing: CGFloat = DS.Space.sm) {
        self.spacing = spacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .greatestFiniteMagnitude ? x : maxWidth, height: y + rowHeight)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Spend added up by what the keys are for. The answer to "where is the money
/// actually going", which a flat list of twelve keys cannot give.
///
/// Shown only when there is more than one category: with a single one it would
/// just repeat the number directly above it.
public struct CategoryBreakdown: View {
    @ObservedObject var model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        let rows = model.state.burnByCategory
        if rows.count > 1 {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                DS.eyebrow("Where it is going")
                FlowLayout(spacing: DS.Space.sm) {
                    ForEach(rows) { entry in
                        chip(entry)
                    }
                }
            }
        }
    }

    private func chip(_ entry: CategoryBurn) -> some View {
        HStack(spacing: DS.Space.xs) {
            Image(systemName: entry.category.symbol)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text(entry.category.title)
                .font(.caption.weight(.medium))
            Text(Fmt.perHour(entry.burn))
                .font(DS.Font.monoSmall)
                .foregroundStyle(entry.tripped ? DS.Tone.breach : DS.Tone.idle)
        }
        .padding(.horizontal, DS.Space.sm + 2)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color(nsColor: .quaternaryLabelColor).opacity(0.22)))
        .accessibilityElement(children: .combine)
    }
}

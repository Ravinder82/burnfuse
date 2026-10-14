import SwiftUI

/// A minimal, axis-free trend line. No chart library, no chrome — just the
/// shape of recent burn so you can read "is this normal?" in half a second.
public struct Sparkline: View {
    let values: [Double]
    var tone: Color = .accentColor
    var lineWidth: CGFloat = 2
    var fill: Bool = true

    public init(values: [Double], tone: Color = .accentColor, lineWidth: CGFloat = 2, fill: Bool = true) {
        self.values = values
        self.tone = tone
        self.lineWidth = lineWidth
        self.fill = fill
    }

    private var normalized: [Double] {
        guard values.count > 1 else { return values }
        let lo = values.min() ?? 0
        let hi = values.max() ?? 1
        let span = hi - lo
        guard span > 0 else { return values.map { _ in 0.5 } }
        return values.map { ($0 - lo) / span }
    }

    public var body: some View {
        GeometryReader { geo in
            let points = normalized.enumerated().map { index, value in
                CGPoint(
                    x: geo.size.width * CGFloat(index) / CGFloat(max(1, normalized.count - 1)),
                    y: geo.size.height * (1 - CGFloat(value))
                )
            }
            if points.count >= 2 {
                ZStack {
                    if fill {
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: geo.size.height))
                            points.forEach { path.addLine(to: $0) }
                            path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                            path.closeSubpath()
                        }
                        .fill(LinearGradient(colors: [tone.opacity(0.28), tone.opacity(0.02)],
                                             startPoint: .top, endPoint: .bottom))
                    }
                    Path { path in
                        path.move(to: points[0])
                        points.dropFirst().forEach { path.addLine(to: $0) }
                    }
                    .stroke(tone, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .drawingGroup()
        .accessibilityHidden(true)
    }
}
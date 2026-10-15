import SwiftUI

/// The BurnFuse mark: a filament that has just given way.
///
/// A fuse is the one part of a circuit whose whole job is to stop the current
/// when it goes too high — which is what this app is. The mark used to draw that
/// as the object itself: a glass body between two metal caps. This is the same
/// idea with everything but the light taken out of it. One filament runs across
/// the tile — green where it starts, amber as it climbs, red where it got hot —
/// and it is *cut* where it gave way, with the spark the break throws.
///
/// It deliberately keeps the design language of the mark it replaces: the same
/// deep graphite tile lit from above, the same single filament in the app's own
/// three colours (the ones that mean settled, climbing and tripped everywhere
/// else), the same proportions and the same tile radius. What is gone is the
/// glass, the metal and the body — the parts that made it a picture of an
/// object rather than a picture of the moment.
///
/// Drawn from shapes rather than shipped as a symbol, so it stays exact from a
/// 15pt sidebar mark to a 1024pt app icon, and nothing about it is a generic AI
/// spark or flame.
public struct FuseMark: View {

    /// What the mark sits on.
    public enum Ground {
        /// The app's own graphite tile: the Dock icon, the README header, and
        /// the mark in the sidebar and the menu-bar panel, where it reads the
        /// same in light and dark because the tile never changes.
        case tile
        /// The filament alone, for a ground that is already dark.
        case bare
    }

    /// `.tile`: the side of the tile. `.bare`: the width of the filament.
    let size: CGFloat
    let ground: Ground

    public init(size: CGFloat, ground: Ground = .tile) {
        self.size = size
        self.ground = ground
    }

    /// macOS's icon grid: on a 1024pt canvas the tile covers 824pt, centred, so
    /// every PNG this app ships carries its own margin.
    public static let canvasInset: CGFloat = 0.098

    /// The tile's corner, as a fraction of the tile. Kept from the mark this
    /// replaces, so nothing about the shape on the Dock moves.
    public static let cornerRatio: CGFloat = 0.278

    /// The filament inside the tile. A little larger on the small tiles the app
    /// draws itself, where the literal proportion would leave the break — the
    /// whole idea — too fine to see.
    var glyphWidth: CGFloat {
        guard ground == .tile else { return size }
        return size * (size < 32 ? 0.84 : 0.76)
    }

    var corner: CGFloat { size * Self.cornerRatio }

    public var body: some View {
        switch ground {
        case .tile: tile
        case .bare: FuseFilament(width: glyphWidth)
        }
    }

    /// Deep graphite, lit from above: a surface for one glowing thing to sit on,
    /// rather than a logo made out of a gradient.
    private var tile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.21), Color(white: 0.08)],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            FuseFilament(width: glyphWidth)
                .offset(y: -size * 0.012)

            // The light falling across the surface, so the filament reads as
            // being under it rather than pasted on top.
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.14), .clear],
                        startPoint: .topLeading, endPoint: .init(x: 0.6, y: 0.55)
                    )
                )

            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: max(1, size * 0.0075))
        }
        .frame(width: size, height: size)
        // Everything the filament throws stays inside the tile.
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }
}

/// The filament alone, at a given width. Height follows at 0.42 of the width —
/// the proportions of the mark this replaces.
///
/// One curve, one gradient, drawn twice: the tail is trimmed just short of the
/// break and the burnt half just past it, so the colour runs continuously
/// across a gap that is unmistakably there. The burnt half is turned slightly
/// up around the break, the way the end of a blown filament lifts away.
struct FuseFilament: View {
    let width: CGFloat

    private var height: CGFloat { width * 0.42 }
    /// A touch thinner than the wire in the mark this replaces: with the glass
    /// gone, the filament is the whole mark, and it needs room around it for the
    /// break to be a break rather than two ends that touch.
    private var wire: CGFloat { max(height * 0.165, 1) }

    /// The app's own language: settled, climbing, tripped — on one filament.
    private var calm: Color { Color(red: 0.34, green: 0.86, blue: 0.58) }
    private var warm: Color { Color(red: 0.99, green: 0.80, blue: 0.28) }
    private var hot: Color { Color(red: 0.98, green: 0.33, blue: 0.15) }

    /// Where the filament gave way, as a fraction of its length. The gap is
    /// deliberately a little wider than twice the wire's thickness — the break
    /// is the whole idea, and it has to read at 16pt as well as at 1024pt.
    private var breakMidpoint: CGFloat { 0.5675 }

    private enum Part {
        case tail, burnt

        var trim: (from: CGFloat, to: CGFloat) {
            self == .tail ? (0.000, 0.495) : (0.640, 1.000)
        }
    }

    /// One gradient across the whole filament, sampled by whatever part of it
    /// is drawn: green at the tail, amber where it breaks, red past it.
    private var gradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: calm, location: 0.00),
                .init(color: warm, location: 0.50),
                .init(color: hot, location: 0.84),
                .init(color: hot, location: 1.00),
            ],
            startPoint: .leading, endPoint: .trailing
        )
    }

    var body: some View {
        ZStack {
            // The light it throws, then the filament, then its white core —
            // the same order a lit wire reads in.
            //
            // The glow is kept close to the wire on purpose: a wide one floods
            // the gap, and a break nobody can see is not a break.
            stroke(.tail, lineWidth: wire * 3.0, blur: wire * 1.0, opacity: 0.30)
            stroke(.burnt, lineWidth: wire * 3.0, blur: wire * 1.0, opacity: 0.30)
            stroke(.tail, lineWidth: wire)
            stroke(.burnt, lineWidth: wire)
            stroke(.tail, lineWidth: wire * 0.30, color: Color.white.opacity(0.50))
            stroke(.burnt, lineWidth: wire * 0.30, color: Color.white.opacity(0.50))
            spark
        }
        .frame(width: width, height: height)
    }

    private func stroke(
        _ part: Part,
        lineWidth: CGFloat,
        color: Color? = nil,
        blur: CGFloat = 0,
        opacity: Double = 1
    ) -> some View {
        let paint: AnyShapeStyle = color.map { AnyShapeStyle($0) } ?? AnyShapeStyle(gradient)
        let trim = part.trim
        return FilamentShape(sag: 0.16)
            .trim(from: trim.from, to: trim.to)
            .stroke(paint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .blur(radius: blur)
            .opacity(opacity)
            .modifier(Sprung(part == .burnt, height: height))
    }

    /// The break itself: a bright point in the gap, and the light it throws.
    /// Tight on purpose — the light of a break should not reach far enough to
    /// look like the wire is still joined.
    private var spark: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.45), warm.opacity(0.22), warm.opacity(0)],
                        center: .center, startRadius: 0, endRadius: height * 0.70
                    )
                )
                .frame(width: height * 1.4, height: height * 1.4)

            Circle()
                .fill(Color.white.opacity(0.92))
                .frame(width: wire * 0.85, height: wire * 0.85)
                .shadow(color: warm.opacity(0.9), radius: wire * 0.9)
        }
        // The gap's midpoint, a touch above the line the wire was on.
        .offset(x: width * (breakMidpoint - 0.5), y: height * 0.04)
    }

    /// The burnt half has sprung: it pivots up around the break, the way the
    /// end of a blown filament lifts away from the gap.
    private struct Sprung: ViewModifier {
        let active: Bool
        let height: CGFloat

        init(_ active: Bool, height: CGFloat) {
            self.active = active
            self.height = height
        }

        @ViewBuilder
        func body(content: Content) -> some View {
            if active {
                content
                    .rotationEffect(.degrees(-6.5), anchor: UnitPoint(x: 0.640, y: 0.5))
                    .offset(y: -height * 0.075)
            } else {
                content
            }
        }
    }
}

/// The wire: straight across, with a slight sag so it reads as a filament under
/// its own weight rather than as a progress bar.
struct FilamentShape: Shape {
    var sag: CGFloat = 0.16

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        path.move(to: CGPoint(x: rect.minX, y: midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: midY),
            control: CGPoint(x: rect.midX, y: midY + rect.height * sag)
        )
        return path
    }
}

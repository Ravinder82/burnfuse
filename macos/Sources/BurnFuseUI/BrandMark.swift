import SwiftUI

/// The BurnFuse mark. Built on SF Symbols so it stays crisp and familiar from
/// a 14pt menu-bar glyph to a 1024pt app icon, and inherits system rendering.
public struct BrandMark: View {
    var size: CGFloat
    var tile: Bool
    var tint: Color

    public init(size: CGFloat = 20, tile: Bool = false, tint: Color = DS.accent) {
        self.size = size
        self.tile = tile
        self.tint = tint
    }

    private var gradient: LinearGradient {
        LinearGradient(
            colors: [tint, Color(red: 0.90, green: 0.30, blue: 0.13)],
            startPoint: .top, endPoint: .bottom
        )
    }

    public var body: some View {
        Group {
            if tile {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor))
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
                    mark(size * 0.6)
                }
                .frame(width: size, height: size)
            } else {
                mark(size)
            }
        }
        .accessibilityHidden(true)
    }

    private func mark(_ dimension: CGFloat) -> some View {
        Image(systemName: "flame.fill")
            .font(.system(size: dimension * 0.92, weight: .medium))
            .foregroundStyle(gradient)
            .frame(width: dimension, height: dimension)
    }
}
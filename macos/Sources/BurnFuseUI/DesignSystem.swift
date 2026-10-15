import SwiftUI

/// Design tokens. One place for spacing, radii, and semantic colour so the
/// whole app reads as a single surface — quiet, legible, and content-first.
public enum DS {

    // MARK: Spacing — 8pt grid
    public enum Space {
        public static let xxs: CGFloat = 2
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 20
        public static let xxl: CGFloat = 28
    }

    public enum Radius {
        public static let small: CGFloat = 8
        public static let medium: CGFloat = 12
        public static let large: CGFloat = 16
        public static let sheet: CGFloat = 20
    }

    /// Semantic state colours, built from system colours so light and dark
    /// appearance, Increased Contrast, and colour filters all keep working.
    public enum Tone {
        public static let calm = Color(nsColor: .systemGreen)
        public static let watch = Color(nsColor: .systemOrange)
        public static let breach = Color(nsColor: .systemRed)
        public static let idle = Color(nsColor: .secondaryLabelColor)

        public static func forAssessment(overCap: Bool, spike: Bool) -> Color {
            if overCap { return breach }
            if spike { return watch }
            return calm
        }
    }

    public enum Font {
        public static let hero = SwiftUI.Font.system(size: 34, weight: .semibold, design: .rounded)
        public static let metric = SwiftUI.Font.system(size: 22, weight: .semibold, design: .rounded)
        public static let mono = SwiftUI.Font.system(size: 12, weight: .medium, design: .monospaced)
        public static let monoSmall = SwiftUI.Font.system(size: 11, weight: .regular, design: .monospaced)
        public static let sectionTitle = SwiftUI.Font.system(size: 13, weight: .semibold)
        public static let label = SwiftUI.Font.system(size: 11, weight: .medium)
    }

    /// The single type scale header used across screens.
    public static func eyebrow(_ text: String) -> some View {
        Text(text.uppercased())
            .font(Font.label)
            .tracking(0.6)
            .foregroundStyle(.tertiary)
    }

    /// BurnFuse accent — a warm, low-key amber that reads on both appearances.
    public static let accent = Color(red: 0.96, green: 0.62, blue: 0.09)
}

/// When set, cards draw as translucent glass instead of an opaque surface. The
/// menu-bar panel turns this on so the panel layers over whatever is behind it.
private struct GlassPanelsKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    var glassPanels: Bool {
        get { self[GlassPanelsKey.self] }
        set { self[GlassPanelsKey.self] = newValue }
    }
}

/// A bordered, content-first container. Uses system materials so it layers
/// correctly in light, dark, and Reduce Transparency.
public struct Card<Content: View>: View {
    var padding: CGFloat
    @ViewBuilder var content: Content

    @Environment(\.glassPanels) private var glassPanels

    public init(padding: CGFloat = DS.Space.lg, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.large, style: .continuous)
                    .fill(glassPanels
                          ? AnyShapeStyle(Material.regular)
                          : AnyShapeStyle(Color(nsColor: .controlBackgroundColor)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.large, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            )
    }
}

/// Section header with an optional trailing accessory.
public struct SectionHeader<Trailing: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var trailing: Trailing

    public init(_ title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: DS.Space.xxs) {
                Text(title).font(DS.Font.sectionTitle)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: DS.Space.sm)
            trailing
        }
    }
}

/// Small status chip: icon + word, so state never relies on colour alone.
public struct StatusChip: View {
    let text: String
    let systemImage: String
    let tone: Color

    public init(text: String, systemImage: String, tone: Color) {
        self.text = text
        self.systemImage = systemImage
        self.tone = tone
    }

    public var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tone)
            .padding(.horizontal, DS.Space.sm)
            .padding(.vertical, DS.Space.xs)
            .background(Capsule().fill(tone.opacity(0.14)))
            .accessibilityElement(children: .combine)
    }
}

/// A thin, one-line progress bar for burn-vs-cap. Track plus a proportional
/// fill, drawn with plain rounded rectangles so it renders identically in the
/// app and in the screenshot renderer.
public struct BurnMeter: View {
    let fill: Double
    let tone: Color

    public init(fill: Double, tone: Color) {
        self.fill = min(max(fill, 0), 1)
        self.tone = tone
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.55))
            .frame(height: 6)
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(tone)
                        .frame(width: max(fill > 0 ? 4 : 0, geo.size.width * fill))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// A quiet inline text button — the "link" style Apple uses inside menus and
/// popovers, without AppKit chrome. Renders cleanly everywhere.
public struct LinkButton: View {
    let title: String
    var systemImage: String?
    var tint: Color
    var enabled: Bool
    let action: () -> Void

    @State private var hovering = false

    public init(_ title: String, systemImage: String? = nil, tint: Color = .accentColor, enabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.enabled = enabled
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Space.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(tint)
            .opacity(enabled ? (hovering ? 1 : 0.85) : 0.5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .onHover { hovering = $0 }
    }
}

/// Filled primary action. Custom-drawn so it looks the same in the app and in
/// offscreen renders, and keeps a clear single-action hierarchy.
public struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    var tint: Color
    var enabled: Bool
    let action: () -> Void

    @State private var hovering = false

    public init(_ title: String, systemImage: String? = nil, tint: Color = DS.accent, enabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.enabled = enabled
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Space.xs) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, DS.Space.md)
            .padding(.vertical, DS.Space.sm - 1)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                    .fill(tint.opacity(enabled ? (hovering ? 0.92 : 1) : 0.4))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .onHover { hovering = $0 }
    }
}

/// Bordered secondary action.
public struct SecondaryButton: View {
    let title: String
    var systemImage: String?
    var tint: Color
    var enabled: Bool
    let action: () -> Void

    @State private var hovering = false

    public init(_ title: String, systemImage: String? = nil, tint: Color = .primary, enabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.enabled = enabled
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Space.xs) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, DS.Space.md)
            .padding(.vertical, DS.Space.sm - 1)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.small, style: .continuous)
                    .fill(Color(nsColor: .quaternaryLabelColor).opacity(hovering ? 0.36 : 0.22))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
        .onHover { hovering = $0 }
    }
}

/// A bare SF Symbol button for row-level actions.
public struct IconButton: View {
    let systemImage: String
    var tint: Color
    var help: String
    let action: () -> Void

    @State private var hovering = false

    public init(_ systemImage: String, tint: Color = .secondary, help: String = "", action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.tint = tint
        self.help = help
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.small - 2, style: .continuous)
                        .fill(Color(nsColor: .quaternaryLabelColor).opacity(hovering ? 0.35 : 0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        // A bare symbol has no name to read out, so VoiceOver would announce the
        // SF Symbol ("trash") rather than what the button does.
        .accessibilityLabel(Text(help.isEmpty ? systemImage : help))
        .onHover { hovering = $0 }
    }
}
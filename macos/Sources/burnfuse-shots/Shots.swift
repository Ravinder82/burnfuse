import SwiftUI
import AppKit
import BurnFuseUI

/// Build-time tooling for BurnFuse, run by `scripts/screenshots.sh`.
///
/// Two jobs, both using the real app views so nothing can drift:
///   1. `shots icon <dir>`   renders the app icon at every size macOS needs
///   2. `shots screens <dir>` renders the app's own screens as PNGs
///
/// The screenshots are produced by SwiftUI's renderer, so they are pixel-accurate
/// captures of the shipping UI — not mockups.
@main
struct BurnFuseShots {
    @MainActor static func main() {
        // SwiftUI resolves its default font through a launched application.
        // Without finishing launch the renderer falls back to a monospaced face.
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        NSApp.finishLaunching()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))

        var args = CommandLine.arguments.dropFirst()
        let command = args.popFirst() ?? "screens"
        let outDir = URL(fileURLWithPath: args.popFirst() ?? "./assets")
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        switch command {
        case "icon":
            renderIcon(to: outDir)
        case "screens":
            renderScreens(to: outDir)
        default:
            FileHandle.standardError.write(Data("usage: burnfuse-shots <icon|screens> <outdir>\n".utf8))
        }
    }

    // MARK: - App icon

    @MainActor static func renderIcon(to dir: URL) {
        let iconset = dir.appendingPathComponent("burnfuse.iconset")
        try? FileManager.default.removeItem(at: iconset)
        try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

        // macOS icon grid: content occupies ~80% of the canvas, squircle radius
        // ~18% of the canvas, centred.
        for size in [16, 32, 64, 128, 256, 512, 1024] {
            let image = render(AppIconView(), size: CGFloat(size), scale: 1)
            guard let data = image else { continue }
            try? data.write(to: dir.appendingPathComponent("icon_\(size).png"))
        }

        // Assemble the .iconset with macOS's expected names.
        let names: [(Int, String)] = [
            (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
            (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
            (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
            (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
            (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
        ]
        for (size, name) in names {
            let source = dir.appendingPathComponent("icon_\(size).png")
            let dest = iconset.appendingPathComponent(name)
            try? FileManager.default.removeItem(at: dest)
            try? FileManager.default.copyItem(at: source, to: dest)
        }
        print("icon: wrote \(dir.path)")
    }

    // MARK: - Screens
    //
    // ImageRenderer cannot draw AppKit-backed controls (text fields, toggles,
    // sliders) — they come out as placeholder boxes. So screens are captured by
    // rendering the live NSView hierarchy into a bitmap, which reflects the real
    // shipping UI including native controls.

    @MainActor static func renderScreens(to dir: URL) {
        let health = demoModel(tripped: false)
        let breach = demoModel(tripped: true)

        snapshot("panel-dark", dir, .dark, width: 340) {
            MainPanel(model: health, width: 340, scrollable: false)
        }
        snapshot("panel-light", dir, .light, width: 340) {
            MainPanel(model: health, width: 340, scrollable: false)
        }
        snapshot("breach-dark", dir, .dark, width: 340) {
            MainPanel(model: breach, width: 340, scrollable: false)
        }
        snapshot("settings-dark", dir, .dark, width: 460, insets: 16) {
            SettingsView(model: health, width: 460, scrollable: false)
        }
        snapshot("settings-light", dir, .light, width: 460, insets: 16) {
            SettingsView(model: health, width: 460, scrollable: false)
        }
        snapshot("insights-dark", dir, .dark, width: 400, insets: 16) {
            InsightsView(model: breach, width: 400, scrollable: false)
        }
        snapshot("_gallery", dir, .dark, width: 420, insets: 16) {
            ComponentGallery()
        }
        print("screens: wrote \(dir.path)")
    }

    /// Capture a SwiftUI view through a real window so native controls render
    /// with their true fonts and styling.
    @MainActor static func snapshot<V: View>(
        _ name: String,
        _ dir: URL,
        _ scheme: ColorScheme,
        width: CGFloat,
        insets: CGFloat = 0,
        @ViewBuilder _ view: () -> V
    ) {
        let appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        let backdrop = scheme == .dark ? Color(white: 0.12) : Color(white: 0.96)
        let hosting = NSHostingView(rootView: AnyView(
            ZStack { backdrop; view().padding(insets) }
        ))
        hosting.appearance = appearance
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: 200)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: 200),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = appearance
        window.contentView = hosting
        // Invisible, but anchored to a real screen so text resolves to the
        // correct system fonts instead of a headless fallback.
        window.alphaValue = 0
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        if let screen = NSScreen.main {
            window.setFrameOrigin(NSPoint(x: screen.frame.minX + 20, y: screen.frame.minY + 20))
        }
        window.makeKeyAndOrderFront(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.25))

        // Settle layout: SwiftUI reports a fitting size before it is final.
        var height: CGFloat = 0
        for _ in 0..<6 {
            hosting.layoutSubtreeIfNeeded()
            let candidate = hosting.fittingSize.height
            if abs(candidate - height) < 0.5 { break }
            height = candidate
            hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
            window.setContentSize(NSSize(width: width, height: height))
        }
        hosting.layoutSubtreeIfNeeded()
        hosting.displayIfNeeded()

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        rep.size = hosting.bounds.size
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: dir.appendingPathComponent("\(name).png"))
        }
        window.orderOut(nil)
    }

    @MainActor static func demoModel(tripped: Bool) -> AppModel {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("burnfuse-shot-\(UUID().uuidString).json")
        let model = AppModel(stateURL: url, pollInterval: 0)
        model.seedDemoData()
        if tripped {
            if let first = model.state.entries.first {
                model.record(keyID: first.id, cost: 9.9)
            }
        }
        return model
    }

    // MARK: - Rendering primitives

    @MainActor static func render<V: View>(
        _ name: String,
        _ dir: URL,
        _ scheme: ColorScheme,
        @ViewBuilder _ view: () -> V
    ) {
        let content = view()
            .environment(\.colorScheme, scheme)
            .background(scheme == .dark ? Color(white: 0.11) : Color(white: 0.97))
        guard let data = render(AnyView(content)) else { return }
        try? data.write(to: dir.appendingPathComponent("\(name).png"))
    }

    @MainActor static func render<V: View>(_ view: V, size: CGFloat, scale: CGFloat) -> Data? {
        let renderer = ImageRenderer(content: view.frame(width: size, height: size))
        renderer.scale = scale
        return png(from: renderer.nsImage)
    }

    @MainActor static func render(_ view: AnyView) -> Data? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return png(from: renderer.nsImage)
    }

    static func png(from image: NSImage?) -> Data? {
        guard let image,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}

/// A development-only contact sheet of every custom control. Rendered to
/// `_gallery.png` so control styling can be reviewed at a glance after changes.
struct ComponentGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.lg) {
            DS.eyebrow("Controls")
            HStack(spacing: DS.Space.sm) {
                PrimaryButton("Primary") {}
                SecondaryButton("Secondary") {}
                LinkButton("Link", systemImage: "plus") {}
                IconButton("gearshape") {}
            }
            HStack(spacing: DS.Space.sm) {
                StatusChip(text: "Armed", systemImage: "checkmark.shield.fill", tone: DS.Tone.calm)
                StatusChip(text: "Spiking", systemImage: "waveform.path.ecg", tone: DS.Tone.watch)
                StatusChip(text: "Tripped", systemImage: "exclamationmark.octagon.fill", tone: DS.Tone.breach)
            }
            VStack(spacing: DS.Space.sm) {
                BurnMeter(fill: 0.15, tone: DS.Tone.calm)
                BurnMeter(fill: 0.6, tone: DS.Tone.watch)
                BurnMeter(fill: 1.0, tone: DS.Tone.breach)
            }
            Sparkline(values: [1, 2, 1.4, 3, 2.2, 4.1, 3.6], tone: DS.Tone.calm)
                .frame(height: 50)
        }
        .padding(DS.Space.xl)
        .frame(width: 420)
        .background(Color(white: 0.11))
    }
}

/// The shipping app icon. A single fuse-flame, warm and legible from 16pt to
struct AppIconView: View {
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let inset = side * 0.098
            let content = side - inset * 2

            ZStack {
                RoundedRectangle(cornerRadius: side * 0.2237, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.00, green: 0.72, blue: 0.20),
                                Color(red: 0.97, green: 0.42, blue: 0.13),
                                Color(red: 0.88, green: 0.20, blue: 0.16),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: side * 0.2237, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.22), lineWidth: max(1, side * 0.006))
                    )
                    .shadow(color: .black.opacity(0.28), radius: side * 0.03, y: side * 0.012)
                    .frame(width: content, height: content)

                flameGlyph(in: content)
            }
            .frame(width: side, height: side)
        }
    }

    /// The mark, drawn as an SF Symbol so the icon matches the in-app mark and
    /// the menu-bar glyph exactly.
    private func flameGlyph(in content: CGFloat) -> some View {
        Image(systemName: "flame.fill")
            .font(.system(size: content * 0.52, weight: .medium))
            .foregroundStyle(
                LinearGradient(
                    colors: [Color(red: 1.0, green: 0.99, blue: 0.95), Color(red: 1.0, green: 0.91, blue: 0.76)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .shadow(color: Color(red: 0.5, green: 0.1, blue: 0.0).opacity(0.32), radius: content * 0.035, y: content * 0.02)
    }
}
import SwiftUI
import AppKit
import BurnFuseUI

/// Build-time tooling for BurnFuse, run by `scripts/screenshots.sh`.
///
/// Two jobs, both using the real app views so nothing can drift:
///   1. `shots icon <dir>`   renders the app icon at every size macOS needs
///   2. `shots screens <dir>` renders the app window, the menu bar, and the
///      marketing card as PNGs
///
/// Everything is produced by rendering the shipping SwiftUI views, so these are
/// pixel-accurate captures of the real UI — not mockups.
@main
struct BurnFuseShots {
    @MainActor static func main() {
        // SwiftUI resolves its default font through a launched application.
        // Without finishing launch the renderer falls back to a monospaced face.
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        NSApp.finishLaunching()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))

        // Assets must be reproducible and must never reveal a real key's
        // presence, so ignore any provider credentials in this environment.
        for name in ["OPENAI_ADMIN_KEY", "OPENROUTER_API_KEY", "ANTHROPIC_ADMIN_KEY",
                     "REPLICATE_API_TOKEN", "GROQ_API_KEY", "AWS_ACCESS_KEY_ID", "BURNFUSE_KEYS"] {
            unsetenv(name)
        }

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
        let climbing = demoModel(tripped: false, heat: 0.72)
        let breach = demoModel(tripped: true)

        // The unified window, one screenshot per section. This is the whole app:
        // there are no other windows to capture.
        let overview = write("window-overview-dark", to: dir,
                             captureWindow(.overview, health, .dark, height: 620))
        write("window-overview-light", to: dir,
              captureWindow(.overview, health, .light, height: 620))
        write("window-breach-dark", to: dir,
              captureWindow(.overview, breach, .dark, height: 700))
        write("window-insights-dark", to: dir,
              captureWindow(.insights, breach, .dark, height: 620))
        write("window-settings-dark", to: dir,
              captureWindow(.settings, health, .dark, height: 980))
        write("window-settings-light", to: dir,
              captureWindow(.settings, health, .light, height: 980))

        // Marketing: the menu-bar glance, and a social card built from the real
        // window render.
        write("menubar-dark", to: dir, captureMenuBar(colorScheme: .dark))
        write("menubar-light", to: dir, captureMenuBar(colorScheme: .light))
        write("menubar-climbing-dark", to: dir, captureMenuBar(colorScheme: .dark, model: climbing))
        write("menubar-breached-dark", to: dir, captureMenuBar(colorScheme: .dark, breached: true))

        write("mini-panel-dark", to: dir, captureMiniPanel(health, .dark))
        write("mini-panel-breach-dark", to: dir, captureMiniPanel(breach, .dark))

        let card = renderSocialCard(window: overview)
        write("social-card", to: dir, card)

        // Dev-only contact sheet for reviewing controls after a change.
        write("_gallery", to: dir, capture(AnyView(ComponentGallery()), scheme: .dark, width: 420, height: 320, fit: true))

        print("screens: wrote \(dir.path)")
    }

    /// The unified window with its title bar, exactly as it appears on screen.
    @MainActor static func captureWindow(
        _ section: AppSection,
        _ model: AppModel,
        _ scheme: ColorScheme,
        width: CGFloat = 900,
        height: CGFloat
    ) -> NSImage? {
        let nav = AppNavigation(section: section)
        let view = WindowChrome(title: "BurnFuse", scheme: scheme) {
            RootView(model: model, nav: nav)
        }
        return capture(AnyView(view), scheme: scheme, width: width, height: height)
    }

    /// A realistic macOS menu bar with the live BurnFuse item in place.
    @MainActor static func captureMenuBar(colorScheme: ColorScheme, breached: Bool = false, model: AppModel? = nil) -> NSImage? {
        let model = model ?? demoModel(tripped: breached)
        let strip = MenuBarStrip(model: model)
        return capture(AnyView(strip), scheme: colorScheme, width: 640, height: 34)
    }

    /// The menu-bar popover: a miniature of the app.
    @MainActor static func captureMiniPanel(_ model: AppModel, _ scheme: ColorScheme) -> NSImage? {
        let panel = MiniPanel(model: model)
            .padding(12)
            .background(Color(white: scheme == .dark ? 0.12 : 0.95))
        return capture(AnyView(panel), scheme: scheme, width: 320, height: 400, fit: true)
    }

    // MARK: - Marketing card

    /// A 1200×630 card for social and product pages, built from the real app
    /// window rather than a redrawn mock-up.
    @MainActor static func renderSocialCard(window: NSImage?) -> NSImage? {
        let card = SocialCard(window: window)
        return capture(AnyView(card), scheme: .dark, width: 1200, height: 630, fit: false)
    }

    // MARK: - Capture

    @MainActor static func capture(
        _ view: AnyView,
        scheme: ColorScheme,
        width: CGFloat,
        height: CGFloat,
        fit: Bool = false
    ) -> NSImage? {
        let appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        let hosting = NSHostingView(rootView: view)
        hosting.appearance = appearance
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
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

        var finalHeight = height
        if fit {
            // Settle layout: SwiftUI reports a fitting size before it is final.
            var measured: CGFloat = 0
            for _ in 0..<6 {
                hosting.layoutSubtreeIfNeeded()
                let candidate = hosting.fittingSize.height
                if abs(candidate - measured) < 0.5 { break }
                measured = candidate
                hosting.frame = NSRect(x: 0, y: 0, width: width, height: measured)
                window.setContentSize(NSSize(width: width, height: measured))
            }
            finalHeight = max(measured, 1)
        }

        hosting.layoutSubtreeIfNeeded()
        hosting.displayIfNeeded()

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            window.orderOut(nil)
            return nil
        }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        rep.size = hosting.bounds.size

        let image = NSImage(size: NSSize(width: width, height: finalHeight))
        image.addRepresentation(rep)
        window.orderOut(nil)
        return image
    }

    /// Write an image to disk as a PNG.
    @MainActor @discardableResult
    static func write(_ name: String, to dir: URL, _ image: NSImage?) -> NSImage? {
        guard let image,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else { return nil }
        try? data.write(to: dir.appendingPathComponent("\(name).png"))
        return image
    }

    @MainActor static func demoModel(tripped: Bool, heat: Double? = nil) -> AppModel {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("burnfuse-shot-\(UUID().uuidString).json")
        let model = AppModel(stateURL: url, pollInterval: 0)
        model.seedDemoData()
        if let heat {
            // Put every key at the same fraction of its cap so the fleet-level
            // colour in the menu bar reflects the heat, not an unused budget.
            for key in model.state.entries {
                model.record(keyID: key.id, cost: key.hourlyLimit * heat)
            }
        }
        if tripped {
            if let first = model.state.entries.first {
                model.record(keyID: first.id, cost: 9.9)
            }
        }
        return model
    }

    // MARK: - Rendering primitives

    @MainActor static func render<V: View>(_ view: V, size: CGFloat, scale: CGFloat) -> Data? {
        let renderer = ImageRenderer(content: view.frame(width: size, height: size))
        renderer.scale = scale
        return png(from: renderer.nsImage)
    }

    static func png(from image: NSImage?) -> Data? {
        guard let image,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}

/// A macOS window frame drawn around a view so a captured screen looks like the
/// window a person actually sees — title bar, traffic lights and all.
struct WindowChrome<Content: View>: View {
    let title: String
    let scheme: ColorScheme
    @ViewBuilder var content: Content

    private var chromeFill: Color {
        scheme == .dark ? Color(white: 0.15) : Color(white: 0.92)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(Color(red: 1.00, green: 0.37, blue: 0.34)).frame(width: 12, height: 12)
                Circle().fill(Color(red: 1.00, green: 0.74, blue: 0.18)).frame(width: 12, height: 12)
                Circle().fill(Color(red: 0.16, green: 0.79, blue: 0.25)).frame(width: 12, height: 12)

                Spacer()

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Color.clear.frame(width: 52, height: 1)
            }
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(chromeFill)

            Divider()
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A realistic macOS menu bar with the real BurnFuse status item in it, for
/// marketing. Everything but the BurnFuse item is scenery; the item itself is
/// the shipping `StatusItemLabel`, so the colour block can never drift from the
/// app.
struct MenuBarStrip: View {
    let model: AppModel

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "apple.logo").font(.system(size: 14, weight: .medium))
            Text("Finder").font(.system(size: 13, weight: .semibold))
            Text("File").font(.system(size: 13))
            Text("Edit").font(.system(size: 13))
            Text("View").font(.system(size: 13))

            Spacer()

            StatusItemLabel(model: model)
                .scaleEffect(1.25)

            Image(systemName: "wifi").font(.system(size: 13))
            Image(systemName: "battery.100percent").font(.system(size: 15))
            Text("9:41").font(.system(size: 13))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 18)
        .frame(height: 34)
        .background(.ultraThinMaterial)
    }
}

/// The 1200×630 marketing card. Icon, name, promise, and the real window.
struct SocialCard: View {
    let window: NSImage?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.09, green: 0.09, blue: 0.11),
                         Color(red: 0.15, green: 0.10, blue: 0.09)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            HStack(alignment: .center, spacing: 48) {
                VStack(alignment: .leading, spacing: 18) {
                    AppMarkTile(size: 84)

                    Text("burnfuse")
                        .font(.system(size: 54, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("A spend breaker for your AI keys.")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color(red: 1.0, green: 0.80, blue: 0.55))

                    Text("Watch burn rate. Cap the damage.\nCut the power before a runaway loop drains your card.")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        pill("Menu bar", "flame")
                        pill("All local", "lock.fill")
                        pill("macOS", "apple.logo")
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: 460, alignment: .leading)

                if let window {
                    Image(nsImage: window)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 620)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.5), radius: 30, y: 16)
                }
            }
            .padding(56)
        }
        .frame(width: 1200, height: 630)
    }

    private func pill(_ text: String, _ symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(.white.opacity(0.10)))
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

/// The shipping app icon, drawn once so every render shares it. A single
/// fuse-flame, warm and legible from 16pt to 1024pt.
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

/// The rounded app-icon tile at a fixed size, for the marketing card.
struct AppMarkTile: View {
    let size: CGFloat
    var body: some View {
        AppIconView()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
    }
}
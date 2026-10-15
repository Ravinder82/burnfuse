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

        // Unsetting the override above is not enough on its own: it would let
        // the renderer fall through to a real ~/.burnfuse/keys.json. Point the
        // store at a throwaway file of obviously fake keys instead, so a shot
        // is the same on every machine and the Settings capture can show what a
        // stored key looks like without ever touching a real one.
        seedFakeKeys()

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

    /// Point the key store at a throwaway file holding obviously fake keys.
    ///
    /// The two live providers the demo data watches get one each, so the
    /// Settings capture shows the state a real person is working towards — a
    /// stored key, its two ends on show, and the row saying it reads itself.
    @MainActor static func seedFakeKeys() {
        let fake = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("burnfuse-shot-keys.json")
        let seeded: [String: String] = [
            // Shaped like the real thing — an OpenAI Admin key, an Anthropic
            // Admin key — and made of characters that read as a key rather than
            // as someone's stand-in: BurnFuse now refuses to send anything it
            // recognises as a placeholder, and a screenshot must not be the one
            // place that shows a warning nobody can see in the app.
            "openai": "sk-admin-01J8ZQ4K7F2M9T3B6N5R8V1X4C7D0G3H6",
            "anthropic": "sk-ant-admin01-K9mQ2rT5vX8zB3nM6pL1wY4cD7fG0hJ3",
        ]
        guard let data = try? JSONSerialization.data(
            withJSONObject: seeded,
            options: [.prettyPrinted, .sortedKeys]
        ) else { return }
        try? data.write(to: fake)
        setenv("BURNFUSE_KEYS", fake.path, 1)
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
        // there are no other windows to capture. Each is measured to its content,
        // so a shot is the whole screen — adding a card or a row cannot quietly
        // push the last one out of frame.
        let overview = write("window-overview-dark", to: dir,
                             captureWindow(.overview, health, .dark))
        write("window-overview-light", to: dir,
              captureWindow(.overview, health, .light))
        write("window-breach-dark", to: dir,
              captureWindow(.overview, breach, .dark))
        write("window-insights-dark", to: dir,
              captureWindow(.insights, breach, .dark))
        // Settings is the tallest section, and the pane is a scroll: the window
        // is measured to whatever the whole screen actually needs, so every
        // row, the add-a-key block and the cards under it are always on show —
        // and so adding a row to the app cannot silently push the last card out
        // of the frame.
        write("window-settings-dark", to: dir,
              captureWindow(.settings, health, .dark, displayStatePath: Self.canonicalStatePath))
        write("window-settings-light", to: dir,
              captureWindow(.settings, health, .light, displayStatePath: Self.canonicalStatePath))

        // The one action that ends the spend, shown where it lives: the switch-off
        // panel open on the OpenAI key's own row, with the account's keys exactly
        // as the provider describes them. The list is seeded rather than fetched,
        // so this shot is the same everywhere and no request leaves the machine.
        let switchOff = demoModel(tripped: false)
        if let openaiKey = switchOff.state.entries.first(where: { $0.provider == "openai" }) {
            switchOff.showSwitchOffPanel(keyID: openaiKey.id)
            switchOff.accountKeys[openaiKey.id] = [
                Revoke.AccountKey(id: "key_01J8ZQ4K7F2M9T3B6N5R8V1X4C7D0G3H6",
                                  name: "OpenAI prod",
                                  hint: "sk-admin…G3H6",
                                  lastUsed: Date().addingTimeInterval(-120),
                                  createdAt: Date().addingTimeInterval(-86_400 * 30)),
                Revoke.AccountKey(id: "key_2M4P6R8T0V2X4Z6B8D0F2H4J6L8N0P2R",
                                  name: "Batch worker",
                                  hint: "sk-proj…T4J8",
                                  lastUsed: Date().addingTimeInterval(-3600 * 20),
                                  createdAt: Date().addingTimeInterval(-86_400 * 6)),
                Revoke.AccountKey(id: "key_3N5Q7S9U1W3Y5A7C9E1G3I5K7M9O1Q3S",
                                  name: "Friday experiment",
                                  hint: "sk-proj…Y1W3",
                                  createdAt: Date().addingTimeInterval(-86_400 * 2),
                                  status: "inactive"),
            ]
        }
        write("window-switchoff-dark", to: dir,
              captureWindow(.settings, switchOff, .dark, displayStatePath: Self.canonicalStatePath))

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
    ///
    /// Pass a height to crop to a fixed frame — the Overview shots do, because
    /// every key has to stay on show. Leave it out and the window is measured
    /// to its content instead, which is how the two tallest screens are
    /// captured: a hand-tuned number here is a number that goes stale the next
    /// time a row grows.
    @MainActor static func captureWindow(
        _ section: AppSection,
        _ model: AppModel,
        _ scheme: ColorScheme,
        width: CGFloat = 900,
        height: CGFloat? = nil,
        displayStatePath: String? = nil
    ) -> NSImage? {
        let nav = AppNavigation(section: section)
        // Settings is captured as the real window with Settings selected, so the
        // shot shows the same chrome, sidebar and background the app does. The
        // add-a-key field gets a key already in it, so the capture shows the
        // moment the whole flow is built around: a pasted key, recognised, with
        // the one line that says what it will do — before anything is saved. The
        // state path shown in About is the real one, not the renderer's temp file.
        let view = WindowChrome(title: "BurnFuse", scheme: scheme) {
            RootView(
                model: model,
                nav: nav,
                previewAddKey: "sk-or-v1-7f3a91c4d8b2e6f0a5c7d9e1b3f4a2c8d6e0f1a3b5c7d9e2",
                displayStatePath: displayStatePath
            )
        }
        let image = capture(AnyView(view), scheme: scheme, width: width,
                            height: height ?? 540, fit: height == nil)
        if height == nil, let image {
            print("  · \(section.rawValue): measured \(Int(image.size.height)) pt")
        }
        return image
    }

    /// Where the app really writes state, so an explainer screenshot can say so
    /// without leaking the temp file the renderer actually used.
    static let canonicalStatePath: String = {
        let home = NSHomeDirectory()
        let path = home + "/.burnfuse/state.json"
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }()

    /// A realistic macOS menu bar with the live BurnFuse item in place.
    @MainActor static func captureMenuBar(colorScheme: ColorScheme, breached: Bool = false, model: AppModel? = nil) -> NSImage? {
        let model = model ?? demoModel(tripped: breached)
        let strip = MenuBarStrip(model: model)
        return capture(AnyView(strip), scheme: colorScheme, width: 640, height: 34)
    }

    /// The menu-bar popover: a miniature of the app.
    @MainActor static func captureMiniPanel(_ model: AppModel, _ scheme: ColorScheme) -> NSImage? {
        // The panel exactly as the app draws it — its own chrome, in a
        // borderless window — with a margin left for the window shadow, which is
        // AppKit's and so is not rendered here.
        let panel = MiniPanel(model: model)
            .padding(14)
        return capture(AnyView(panel), scheme: scheme, width: 324, height: 400, fit: true)
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

                    Text("Watch the burn rate. Cap the damage.\nKnow within a minute, not in the morning.")
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

/// The shipping app icon, drawn once so every render shares it: the same
/// `FuseMark` the app draws in its own sidebar, on macOS's icon grid, with the
/// shadow the Dock adds.
struct AppIconView: View {
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let content = side * (1 - FuseMark.canvasInset * 2)

            FuseMark(size: content)
                .shadow(color: .black.opacity(0.30), radius: side * 0.03, y: side * 0.012)
                .frame(width: side, height: side)
        }
    }
}

/// The rounded app-icon tile at a fixed size, for the marketing card.
struct AppMarkTile: View {
    let size: CGFloat
    var body: some View {
        AppIconView()
            .frame(width: size, height: size)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: size * (1 - FuseMark.canvasInset * 2) * FuseMark.cornerRatio,
                    style: .continuous
                )
            )
    }
}

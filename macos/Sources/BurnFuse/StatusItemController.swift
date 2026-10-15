import AppKit
import SwiftUI
import Combine
import BurnFuseUI

/// Owns the menu-bar item directly rather than going through SwiftUI's
/// `MenuBarExtra`.
///
/// `MenuBarExtra` renders its label as a template image — the system flattens it
/// to a monochrome glyph on a transparent background, which is why the colour
/// block appeared as a plain white flame and number. Managing the `NSStatusItem`
/// ourselves lets us draw the real `StatusItemLabel` into a non-template image,
/// so the colour the app intends is the colour you see.
///
/// Left click opens the panel (a miniature of the app). Right click opens a menu
/// with the housekeeping actions.
///
/// The click shows the panel and nothing else: it does not activate the app, so
/// it does not bring the app's window forward. `MiniPanelHost` holds the panel
/// and the reasons it is not an `NSPopover`.
@MainActor
final class StatusItemController: NSObject {
    private let model: AppModel
    private let statusItem: NSStatusItem
    private var panel: MiniPanelHost!
    private var cancellable: AnyCancellable?

    init(model: AppModel) {
        self.model = model
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        statusItem.button?.target = self
        statusItem.button?.action = #selector(handleClick)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.imagePosition = .imageOnly

        panel = MiniPanelHost(content: MiniPanel(
            model: model,
            onOpen: { [weak self] section in
                self?.panel.hide()
                AppRouter.shared.show(section)
            },
            onQuit: { NSApplication.shared.terminate(nil) }
        ))

        refresh()

        // `objectWillChange` fires before the change lands, so re-render on the
        // next runloop turn to pick up the new value.
        cancellable = model.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.refresh() }
        }
    }

    /// Redraw the item from the current state. Rendered as a non-template bitmap
    /// so the capsule fill and the live number appear exactly as designed, and
    /// at 2× so it stays crisp on Retina displays.
    private func refresh() {
        guard let button = statusItem.button else { return }
        let image = render(StatusItemLabel(model: model))
        image?.isTemplate = false
        button.image = image
        button.toolTip = tooltip
        button.setAccessibilityLabel(tooltip)
    }

    private var tooltip: String {
        if model.state.hasBreach {
            return "BurnFuse — \(model.state.tripped.count) key\(model.state.tripped.count == 1 ? "" : "s") tripped"
        }
        if model.state.entries.isEmpty {
            return "BurnFuse — no keys watched"
        }
        return "BurnFuse — \(Fmt.perHour(model.state.totalBurn)) burning now"
    }

    private func render<V: View>(_ view: V) -> NSImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage, image.size.width > 0 else { return nil }
        image.isTemplate = false
        return image
    }

    // MARK: - Interaction

    @objc private func handleClick() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        panel.toggle(relativeTo: button)
    }

    // MARK: - For the self-check in scripts/verify.sh

    var isPanelShown: Bool { panel.isShown }

    /// Show the panel the way a click does, so the launch check can assert what
    /// a click does and does not do to the rest of the screen.
    func showPanelForSelfCheck() {
        guard let button = statusItem.button else { return }
        panel.show(relativeTo: button)
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Open BurnFuse", action: #selector(openOverview), keyEquivalent: "")
        menu.addItem(withTitle: "Insights", action: #selector(openInsights), keyEquivalent: "")
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: "")

        menu.addItem(.separator())

        let summary = NSMenuItem(
            title: model.state.hasBreach
                ? "\(model.state.tripped.count) tripped"
                : "\(Fmt.perHour(model.state.totalBurn)) burning now",
            action: nil,
            keyEquivalent: ""
        )
        summary.isEnabled = false
        menu.addItem(summary)

        if model.state.hasBreach {
            menu.addItem(withTitle: "Re-arm all", action: #selector(rearmAll), keyEquivalent: "")
        }
        let cut = NSMenuItem(title: "Trip all keys", action: #selector(cutAll), keyEquivalent: "")
        cut.isEnabled = !model.state.entries.isEmpty
            && model.state.tripped.count != model.state.entries.count
        menu.addItem(cut)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit BurnFuse", action: #selector(quit), keyEquivalent: "q")

        for item in menu.items where item.action != nil {
            item.target = self
        }
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openOverview() { AppRouter.shared.show(.overview) }
    @objc private func openInsights() { AppRouter.shared.show(.insights) }
    @objc private func openSettings() { AppRouter.shared.show(.settings) }
    @objc private func rearmAll() { model.armAll() }
    @objc private func cutAll() { model.tripAll() }
    @objc private func quit() { NSApplication.shared.terminate(nil) }
}
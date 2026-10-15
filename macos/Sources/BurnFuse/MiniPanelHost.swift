import AppKit
import SwiftUI

/// The window that hangs off the menu-bar item.
///
/// A `.nonactivatingPanel`, deliberately not an `NSPopover`. A popover can only
/// be interactive while its app is active, and activating the app is what
/// dragged the whole BurnFuse window forward over whatever you were doing —
/// asking for a glance at the burn rate reorganised the screen. A nonactivating
/// panel takes clicks, can take key without activating, and joins the Space you
/// are on, which is what a menu-bar item is supposed to do. The full window
/// opens only from the actions inside the panel that ask for it.
@MainActor
final class MiniPanelHost {

    private let panel: MiniPanelWindow
    /// The menu-bar item's frame in screen coordinates, so a click on the item
    /// is left to the item (it is the toggle) while a click anywhere else closes
    /// the panel.
    private var anchorRect: NSRect = .zero
    private var globalClick: Any?
    private var localClick: Any?
    private var escape: Any?
    private var observings: [NSObjectProtocol] = []

    init<Content: View>(content: Content) {
        let hosting = NSHostingController(rootView: content)
        hosting.sizingOptions = [.preferredContentSize]

        panel = MiniPanelWindow(
            contentRect: NSRect(x: 0, y: 0, width: 296, height: 320),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hosting
        panel.isFloatingPanel = true
        panel.level = .statusBar
        // A panel that hid itself whenever the app was not active would vanish
        // the moment it appeared: the app is deliberately not activated.
        panel.hidesOnDeactivate = false
        // Take key only when something in here actually needs it, so a glance
        // does not take focus away from what you were typing in.
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
    }

    var isShown: Bool { panel.isVisible }

    func toggle(relativeTo button: NSStatusBarButton) {
        if panel.isVisible { hide() } else { show(relativeTo: button) }
    }

    func show(relativeTo button: NSStatusBarButton) {
        if let buttonWindow = button.window {
            anchorRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        }
        // Size to the content before placing it, so the panel lands under the
        // item rather than halfway across the screen.
        if let content = panel.contentViewController?.view {
            panel.setContentSize(content.fittingSize)
        }
        place()
        // The whole point: order the panel in without activating anything.
        // `orderFrontRegardless` is what shows a window for an app that stays in
        // the background.
        panel.orderFrontRegardless()
        watchForDismissal()
    }

    func hide() {
        stopWatching()
        panel.orderOut(nil)
    }

    // MARK: - Placement

    private func place() {
        let size = panel.frame.size
        let anchorPoint = NSPoint(x: anchorRect.midX, y: anchorRect.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(anchorPoint) } ?? NSScreen.main

        // Just under the menu bar item, centred on it, and never off the edge of
        // the screen it was clicked on.
        var origin = NSPoint(x: anchorRect.midX - size.width / 2, y: anchorRect.minY - size.height - 8)
        if let visible = screen?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
            origin.y = max(origin.y, visible.minY + 8)
        }
        panel.setFrameOrigin(origin)
    }

    // MARK: - Dismissing

    private func watchForDismissal() {
        stopWatching()

        // A click in another app, on the desktop, or on another menu-bar item.
        // Clicks inside this panel are local events and never reach a global
        // monitor, so anything arriving here is somewhere else entirely.
        globalClick = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, !NSPointInRect(NSEvent.mouseLocation, self.anchorRect) else { return }
            self.hide()
        }

        // The same thing for clicks inside this app — the window behind the
        // panel, or the Dock icon while the app is frontmost.
        localClick = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, self.panel.isVisible else { return event }
            if event.window === self.panel { return event }
            if NSPointInRect(NSEvent.mouseLocation, self.anchorRect) { return event }
            self.hide()
            return event
        }

        escape = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            self?.hide()
            return nil
        }

        // If the app itself is brought forward or put away, the glance is over.
        for name in [NSApplication.didBecomeActiveNotification,
                     NSApplication.didResignActiveNotification,
                     NSApplication.didHideNotification] {
            observings.append(NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.hide() }
            })
        }
    }

    private func stopWatching() {
        if let globalClick { NSEvent.removeMonitor(globalClick) }
        if let localClick { NSEvent.removeMonitor(localClick) }
        if let escape { NSEvent.removeMonitor(escape) }
        globalClick = nil
        localClick = nil
        escape = nil
        observings.forEach { NotificationCenter.default.removeObserver($0) }
        observings = []
    }
}

/// A window that can be clicked and shown without activating the app, and that
/// never pretends to be the app's main window.
private final class MiniPanelWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

import SwiftUI
import AppKit
import UserNotifications
import BurnFuseUI

/// The BurnFuse app.
///
/// A real macOS app: it has a Dock icon and an app menu, and it opens its window
/// on launch. On top of that it keeps a live, colour-coded item in the menu bar,
/// so the burn is always one glance away. The window holds everything —
/// Overview, Insights and Settings behind a sidebar.
@main
struct BurnFuseApp: App {
    @StateObject private var model: AppModel
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    init() {
        let model = AppModel()
        _model = StateObject(wrappedValue: model)
        AppDelegate.sharedModel = model
    }

    var body: some Scene {
        Window("BurnFuse", id: "main") {
            RootView(model: model, nav: AppRouter.shared.nav)
                .background(WindowActionCatcher())
        }
        .defaultSize(width: 900, height: 640)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { AppRouter.shared.show(.settings) }
                    .keyboardShortcut(",", modifiers: .command)
                Button("Insights") { AppRouter.shared.show(.insights) }
                    .keyboardShortcut("i", modifiers: .command)
            }
            CommandGroup(replacing: .newItem) {}
        }
    }
}

/// Routes "open the app" requests — from the menu bar, the Dock, or a menu
/// command — to the one window, creating or focusing it as needed.
@MainActor
public final class AppRouter {
    public static let shared = AppRouter()

    let nav = AppNavigation()

    /// Captured from the live scene so we can reopen the window after it closes.
    var openWindowAction: ((String) -> Void)?

    func install(openWindow: @escaping (String) -> Void) {
        openWindowAction = openWindow
    }

    /// Show the main window on a given section.
    public func show(_ section: AppSection) {
        nav.section = section
        revealWindow()
    }

    func revealWindow() {
        if let window = NSApp.windows.first(where: { $0.canBecomeMain && !($0 is NSPanel) }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindowAction?("main")
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// Sits invisibly inside the window and hands the scene's `openWindow` action to
/// `AppRouter`. SwiftUI's environment is only reachable from inside a scene, so
/// this is how the menu bar can reopen the window after it has been closed.
private struct WindowActionCatcher: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear { AppRouter.shared.install { openWindow(id: $0) } }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var sharedModel: AppModel?

    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A regular app: Dock icon, app menu, real windows.
        NSApp.setActivationPolicy(.regular)

        guard let model = AppDelegate.sharedModel else { return }

        model.onIncident = { incident in
            AppDelegate.notify(incident)
        }
        // Read live spend in the background so the window and the menu bar stay
        // current without anyone touching anything.
        model.refreshInterval = 60

        // The menu-bar item is managed directly so its colour block renders as
        // drawn; SwiftUI's MenuBarExtra would template it to monochrome.
        statusItem = StatusItemController(model: model)

        if CommandLine.arguments.contains("--panel-self-check") {
            runPanelSelfCheck()
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Prove what a click on the menu-bar item does, and does not, do.
    ///
    /// The bug this exists for: showing the panel activated the app, so the whole
    /// BurnFuse window came forward over whatever was on screen — a glance at the
    /// burn rate reorganised your desktop. Here the app is put in the background
    /// with its window away, the panel is shown exactly as a click shows it, and
    /// the check fails if the app became active again or any window came back.
    private func runPanelSelfCheck() {
        guard let statusItem else { exit(2) }

        // As if the window had been closed and you had gone back to work.
        for window in NSApp.windows { window.orderOut(nil) }
        NSApp.deactivate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            statusItem.showPanelForSelfCheck()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                let panelShown = statusItem.isPanelShown
                let appActive = NSApp.isActive
                let windowVisible = NSApp.windows.contains { $0.isVisible && !($0 is NSPanel) }
                print("SELF-CHECK panel-shown=\(panelShown) app-active=\(appActive) window-visible=\(windowVisible)")
                exit(panelShown && !appActive && !windowVisible ? 0 : 1)
            }
        }
    }

    /// Closing the window leaves BurnFuse running in the menu bar.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// Clicking the Dock icon brings the window back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { AppRouter.shared.revealWindow() }
        return true
    }

    /// Local notification when the breaker fires. Purely on-device.
    static func notify(_ incident: Incident) {
        let content = UNMutableNotificationContent()
        content.title = "Breaker tripped"
        content.subtitle = incident.name
        // The trip is only useful if whoever sees it knows the one action that
        // ends the spend. The key being paused does not stop the provider
        // billing, so the notification named where to revoke it.
        let provider = AppDelegate.sharedModel?.state.entries
            .first(where: { $0.id == incident.entryId })?.provider
        content.body = "\(Fmt.perHour(incident.reading)) against a \(Fmt.money(incident.hourlyLimit)) cap — \(incident.reason). \(Providers.revokeHint(for: provider ?? "custom"))"
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "burnfuse-\(Int(incident.at))",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
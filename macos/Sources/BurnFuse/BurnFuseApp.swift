import SwiftUI
import AppKit
import UserNotifications
import BurnFuseUI

/// The BurnFuse app.
///
/// One window holds everything — Overview, Insights and Settings behind a
/// sidebar. The menu bar keeps a live, colour-coded burn visible at all times,
/// and clicking it opens a miniature of the app you can keep an eye on.
@main
struct BurnFuseApp: App {
    @StateObject private var model: AppModel
    @StateObject private var nav = AppNavigation()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    init() {
        let model = AppModel()
        _model = StateObject(wrappedValue: model)
        AppDelegate.sharedModel = model
    }

    var body: some Scene {
        Window("BurnFuse", id: "main") {
            RootView(model: model, nav: nav)
        }
        .defaultSize(width: 900, height: 640)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings") { open(.settings) }
                    .keyboardShortcut(",", modifiers: .command)
                Button("Insights") { open(.insights) }
                    .keyboardShortcut("i", modifiers: .command)
            }
        }

        MenuBarExtra {
            MenuBarContent(model: model, nav: nav)
        } label: {
            StatusItemLabel(model: model)
        }
        .menuBarExtraStyle(.window)
    }

    private func open(_ section: AppSection) {
        nav.section = section
        WindowActivator.shared.open()
    }
}

/// The menu-bar popover: a miniature of the app, not a menu.
struct MenuBarContent: View {
    @ObservedObject var model: AppModel
    @ObservedObject var nav: AppNavigation

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        MiniPanel(
            model: model,
            onOpen: { section in
                nav.section = section
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            },
            onQuit: { NSApplication.shared.terminate(nil) }
        )
    }
}

/// Brings the unified window to the front, creating nothing new — the Window
/// scene already owns it.
@MainActor
final class WindowActivator {
    static let shared = WindowActivator()
    func open() {
        if let window = NSApp.windows.first(where: { $0.canBecomeMain && !($0 is NSPanel) }) {
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var sharedModel: AppModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppDelegate.sharedModel?.onIncident = { incident in
            AppDelegate.notify(incident)
        }
        // Read live spend in the background so the window and the menu bar stay
        // current without anyone touching anything.
        AppDelegate.sharedModel?.refreshInterval = 60
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// Local notification when the breaker fires. Purely on-device.
    static func notify(_ incident: Incident) {
        let content = UNMutableNotificationContent()
        content.title = "Breaker tripped"
        content.subtitle = incident.name
        content.body = "\(Fmt.perHour(incident.reading)) against a \(Fmt.money(incident.hourlyLimit)) cap. \(incident.reason.capitalized)."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "burnfuse-\(Int(incident.at))",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
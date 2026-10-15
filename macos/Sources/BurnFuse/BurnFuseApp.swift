import SwiftUI
import AppKit
import UserNotifications
import BurnFuseUI

/// The BurnFuse app.
///
/// One window holds everything — Overview, Insights and Settings behind a
/// sidebar. The menu bar keeps the live burn visible and can bring that window
/// forward, so you can glance at the number or open the whole app.
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
                Button("Insights") { open(.overview) }
                    .keyboardShortcut("i", modifiers: .command)
            }
        }

        MenuBarExtra {
            MenuBarMenu(model: model, nav: nav)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.menu)
    }

    private func open(_ section: AppSection) {
        nav.section = section
        WindowActivator.shared.open()
    }
}

/// The menu-bar item. A small menu: open the window on any section, or act on
/// every key at once. The number itself is always readable without opening it.
struct MenuBarMenu: View {
    @ObservedObject var model: AppModel
    @ObservedObject var nav: AppNavigation

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open BurnFuse") { show(.overview) }
        Button("Insights") { show(.insights) }
        Button("Settings…") { show(.settings) }

        Divider()

        Text(model.state.hasBreach
             ? "\(model.state.tripped.count) tripped"
             : "\(Fmt.perHour(model.state.totalBurn)) burning now")

        if model.state.hasBreach {
            Button("Re-arm all") { model.armAll() }
        }
        Button("Cut all power") { model.tripAll() }
            .disabled(model.state.entries.isEmpty || model.state.tripped.count == model.state.entries.count)

        Divider()

        Button("Quit BurnFuse") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func show(_ section: AppSection) {
        nav.section = section
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
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

/// The menu-bar title. Shows the live burn and switches to an alert glyph the
/// moment anything trips, so you can read it without opening the window.
struct MenuBarLabel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        let breached = model.state.hasBreach
        HStack(spacing: 3) {
            Image(systemName: breached ? "flame.fill" : "flame")
            Text(breached ? "!" : shortText)
        }
        .accessibilityLabel(breached
            ? "BurnFuse, breaker tripped"
            : "BurnFuse, \(shortText) per hour")
    }

    private var shortText: String {
        let total = model.state.totalBurn
        if total == 0 { return "$0" }
        if total < 10 { return String(format: "$%.2f", total) }
        return String(format: "$%.0f", total)
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
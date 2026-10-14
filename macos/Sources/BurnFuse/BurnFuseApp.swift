import SwiftUI
import AppKit
import UserNotifications
import BurnFuseUI

/// The BurnFuse menu-bar app.
///
/// One entry point, no windows on launch, no dock icon — it sits next to your
/// clock and tells you the truth about what your AI keys are spending.
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
        MenuBarExtra {
            MainPanel(
                model: model,
                onOpenSettings: { SettingsWindowController.shared.show(model: model) },
                onQuit: { NSApplication.shared.terminate(nil) }
            )
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { SettingsWindowController.shared.show(model: model) }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

/// The menu-bar title. Shows the live burn and switches to an alert glyph the
/// moment anything trips, so you can read it without opening the panel.
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
    private var bannerShownFor: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppDelegate.sharedModel?.onIncident = { incident in
            AppDelegate.notify(incident)
        }
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

/// A single reusable settings window, opened from the panel or ⌘,.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show(model: AppModel) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = SettingsView(model: model)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "BurnFuse Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.setContentSize(NSSize(width: 460, height: 720))
        window.isReleasedWhenClosed = false
        window.center()
        window.delegate = self
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
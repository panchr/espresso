import AppKit
import SwiftUI

/// Owns the settings window. A menubar app has no main window to reuse, so the
/// window is built once, kept alive across closes, and re-shown on demand.
final class SettingsWindowController {
    private let model: SettingsModel
    private var window: NSWindow?

    init(model: SettingsModel) {
        self.model = model
    }

    func show() {
        if window == nil {
            let created = makeWindow()
            created.center()
            window = created
        }
        // An .accessory app is never the active app on its own, so without
        // this the window opens behind whatever the user was working in.
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        window?.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Espresso Settings"
        window.contentViewController = NSHostingController(rootView: SettingsView(model: model))
        // Closing the window must not deallocate it; it is shown again as-is.
        window.isReleasedWhenClosed = false
        return window
    }
}

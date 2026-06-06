import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Menubar-only app: no Dock icon, no main window.
app.setActivationPolicy(.accessory)
app.run()

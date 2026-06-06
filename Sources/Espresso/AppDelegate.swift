import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let durations: [(title: String, seconds: TimeInterval?)] = [
        ("30 Minutes", 30 * 60),
        ("1 Hour", 60 * 60),
        ("2 Hours", 2 * 60 * 60),
        ("4 Hours", 4 * 60 * 60),
        ("Forever", nil),
    ]

    private let caffeinate = CaffeinateController()
    private var statusItem: NSStatusItem!
    private var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // Stable autosave name so a user-dragged menubar position persists across launches.
        statusItem.autosaveName = "EspressoStatusItem"
        if let button = statusItem.button {
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        caffeinate.onExpire = { [weak self] in self?.sessionChanged() }
        refreshStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        caffeinate.stop()
    }

    // MARK: - Click handling

    @objc private func statusItemClicked() {
        let isRightClick = NSApp.currentEvent?.type == .rightMouseUp
        showMenu(isRightClick ? rightClickMenu() : leftClickMenu())
    }

    /// NSStatusItem only auto-shows a menu assigned to `menu`, which would
    /// swallow the click action. Assign it just for this click, then clear it
    /// in menuDidClose so left and right clicks can show different menus.
    private func showMenu(_ menu: NSMenu) {
        menu.delegate = self
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil
    }

    private func leftClickMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Keep Awake For", action: nil, keyEquivalent: ""))
        for (index, duration) in Self.durations.enumerated() {
            let item = NSMenuItem(title: duration.title, action: #selector(startSession(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            menu.addItem(item)
        }
        return menu
    }

    private func rightClickMenu() -> NSMenu {
        let menu = NSMenu()
        if caffeinate.isActive {
            let title = caffeinate.endDate == nil ? "Stop Keeping Awake" : "Cancel Timer"
            let cancel = NSMenuItem(title: title, action: #selector(cancelSession), keyEquivalent: "")
            cancel.target = self
            menu.addItem(cancel)
            menu.addItem(.separator())
        }
        menu.addItem(NSMenuItem(title: "Quit Espresso", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    // MARK: - Session management

    @objc private func startSession(_ sender: NSMenuItem) {
        caffeinate.start(duration: Self.durations[sender.tag].seconds)
        sessionChanged()
    }

    @objc private func cancelSession() {
        caffeinate.stop()
        sessionChanged()
    }

    private func sessionChanged() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        if caffeinate.isActive, caffeinate.endDate != nil {
            let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                self?.refreshStatusItem()
            }
            timer.tolerance = 0.1
            // .common keeps the countdown ticking while a menu is open.
            RunLoop.main.add(timer, forMode: .common)
            refreshTimer = timer
        }
        refreshStatusItem()
    }

    // MARK: - Status item display

    private func refreshStatusItem() {
        guard let button = statusItem.button else { return }
        if caffeinate.isActive {
            button.image = Self.icon(named: "cup.and.saucer.fill")
            if let endDate = caffeinate.endDate {
                button.title = " " + Self.countdownText(until: endDate)
            } else {
                button.title = " ∞"
            }
        } else {
            button.image = Self.icon(named: "cup.and.saucer")
            button.title = ""
        }
    }

    private static func icon(named name: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: "Espresso")
    }

    private static func countdownText(until endDate: Date) -> String {
        let remaining = max(0, Int(endDate.timeIntervalSinceNow.rounded(.up)))
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        let seconds = remaining % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

import AppKit
import EspressoCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let durations: [(label: String, seconds: TimeInterval?)] = [
        ("30m", 30 * 60),
        ("1h", 60 * 60),
        ("2h", 2 * 60 * 60),
        ("4h", 4 * 60 * 60),
        ("∞", nil),
    ]

    private let caffeinate = CaffeinateController()
    private let loginItem = LoginItemController()
    private let model = SessionModel()
    private var statusItem: NSStatusItem!
    private var refreshTimer: Timer?
    private lazy var popover = makePopover()

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
        // Restores the login item if an upgrade invalidated it, so relaunching
        // the app from /Applications is enough to fix Start at Login.
        loginItem.reconcile()
        refreshStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        caffeinate.stop()
    }

    // MARK: - Click handling

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu(rightClickMenu())
        } else {
            togglePopover()
        }
    }

    private func makePopover() -> NSPopover {
        let popover = NSPopover()
        popover.behavior = .transient
        let panel = StatusPanelView(
            model: model,
            options: Self.durations.map(\.label),
            onSelect: { [weak self] index in self?.startSession(at: index) },
            onClear: { [weak self] in self?.cancelSession() },
            onQuit: { NSApp.terminate(nil) }
        )
        let host = NSHostingController(rootView: panel)
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host
        return popover
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            // Activation makes the transient popover dismiss on outside clicks.
            if #available(macOS 14.0, *) {
                NSApp.activate()
            } else {
                NSApp.activate(ignoringOtherApps: true)
            }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
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

    private func rightClickMenu() -> NSMenu {
        let menu = NSMenu()
        if caffeinate.isActive {
            let clear = NSMenuItem(title: "Clear", action: #selector(cancelSession), keyEquivalent: "")
            clear.target = self
            menu.addItem(clear)
            menu.addItem(.separator())
        }
        let login = NSMenuItem(title: "Start at Login", action: #selector(toggleStartAtLogin), keyEquivalent: "")
        login.target = self
        login.state = loginItem.isEnabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Espresso", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    @objc private func toggleStartAtLogin() {
        // Only the user can restore consent they revoked in System Settings,
        // so send them there rather than failing silently.
        if loginItem.toggle() == .needsUserApproval {
            loginItem.openSystemSettings()
        }
    }

    // MARK: - Session management

    private func startSession(at index: Int) {
        caffeinate.start(duration: Self.durations[index].seconds)
        model.selectedIndex = index
        sessionChanged()
        popover.performClose(nil)
    }

    @objc private func cancelSession() {
        caffeinate.stop()
        sessionChanged()
        popover.performClose(nil)
    }

    private func sessionChanged() {
        model.isActive = caffeinate.isActive
        if !caffeinate.isActive {
            model.selectedIndex = nil
        }
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
                button.title = " " + Countdown.text(remaining: endDate.timeIntervalSinceNow)
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
}

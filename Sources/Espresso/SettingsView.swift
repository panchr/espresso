import SwiftUI

/// Persisted user preferences, shared between the settings window and the
/// app delegate that acts on them.
final class SettingsModel: ObservableObject {
    private enum DefaultsKey {
        static let stopWhenLidCloses = "StopWhenLidCloses"
    }

    /// Whether closing the lid should end an active keep-awake session.
    @Published var stopWhenLidCloses: Bool {
        didSet { defaults.set(stopWhenLidCloses, forKey: DefaultsKey.stopWhenLidCloses) }
    }

    /// Mirrors `SMAppService`, which owns the real state — this is only a
    /// cache for the view, refreshed whenever the window is shown.
    @Published private(set) var startAtLogin: Bool

    /// False on Macs that report no lid state, which leaves the preference
    /// visible but inert rather than silently doing nothing.
    let lidStateAvailable: Bool

    private let defaults: UserDefaults
    private let loginItem: LoginItemController

    init(defaults: UserDefaults = .standard, loginItem: LoginItemController, lidStateAvailable: Bool) {
        self.defaults = defaults
        self.loginItem = loginItem
        self.lidStateAvailable = lidStateAvailable
        // On by default: a closed lid is a clear signal the Mac is no longer
        // being used, and leaving it awake is the surprising outcome.
        defaults.register(defaults: [DefaultsKey.stopWhenLidCloses: true])
        stopWhenLidCloses = defaults.bool(forKey: DefaultsKey.stopWhenLidCloses)
        startAtLogin = loginItem.isEnabled
    }

    /// Re-reads the login item, which the user can change in System Settings
    /// while Espresso is running.
    func refreshStartAtLogin() {
        startAtLogin = loginItem.isEnabled
    }

    func toggleStartAtLogin() {
        // Only the user can restore consent they revoked in System Settings,
        // so send them there rather than failing silently.
        if loginItem.toggle() == .needsUserApproval {
            loginItem.openSystemSettings()
        }
        refreshStartAtLogin()
    }
}

/// Contents of the settings window.
struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            setting(
                title: "Start at Login",
                explanation: "Launch Espresso automatically when you log in.",
                // SMAppService is the source of truth, so the toggle reports
                // what it accepted rather than what was clicked.
                isOn: Binding(
                    get: { model.startAtLogin },
                    set: { _ in model.toggleStartAtLogin() }
                ),
                enabled: true
            )
            Divider()
            setting(
                title: "Stop when the lid closes",
                explanation: lidExplanation,
                isOn: $model.stopWhenLidCloses,
                enabled: model.lidStateAvailable
            )
        }
        .padding(20)
        .frame(width: 340, alignment: .leading)
    }

    private func setting(
        title: String,
        explanation: String,
        isOn: Binding<Bool>,
        enabled: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(title, isOn: isOn)
                .disabled(!enabled)
            Text(explanation)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var lidExplanation: String {
        model.lidStateAvailable
            ? "Ends an active session when you close the laptop, so a docked Mac doesn't stay awake unattended."
            : "This Mac doesn't report a lid state, so there is nothing to detect."
    }
}

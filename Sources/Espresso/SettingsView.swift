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

    /// False on Macs that report no lid state, which leaves the preference
    /// visible but inert rather than silently doing nothing.
    let lidStateAvailable: Bool

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard, lidStateAvailable: Bool) {
        self.defaults = defaults
        self.lidStateAvailable = lidStateAvailable
        // On by default: a closed lid is a clear signal the Mac is no longer
        // being used, and leaving it awake is the surprising outcome.
        defaults.register(defaults: [DefaultsKey.stopWhenLidCloses: true])
        stopWhenLidCloses = defaults.bool(forKey: DefaultsKey.stopWhenLidCloses)
    }
}

/// Contents of the settings window.
struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Stop when the lid closes", isOn: $model.stopWhenLidCloses)
                .disabled(!model.lidStateAvailable)
            Text(explanation)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(width: 340, alignment: .leading)
    }

    private var explanation: String {
        model.lidStateAvailable
            ? "Ends an active session when you close the laptop, so a docked Mac doesn't stay awake unattended."
            : "This Mac doesn't report a lid state, so there is nothing to detect."
    }
}

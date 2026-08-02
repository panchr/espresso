import AppKit
import EspressoCore
import ServiceManagement

/// Bridges `SMAppService` and the persisted "Start at Login" preference,
/// applying `LoginItemPolicy` at launch so the registration survives upgrades.
final class LoginItemController {
    private enum DefaultsKey {
        static let enabled = "StartAtLogin"
        static let bundlePath = "StartAtLoginBundlePath"
        static let bundleVersion = "StartAtLoginBundleVersion"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Reconciles the system's registration with the stored preference. Call at
    /// launch: this is what re-creates the login item after the bundle has been
    /// replaced by an upgrade or reinstall.
    func reconcile() {
        let preference = storedPreference
        let recordedBundleExists = preference.map {
            FileManager.default.fileExists(atPath: $0.bundle.path)
        } ?? false

        switch LoginItemPolicy.action(
            preference: preference,
            status: Self.status,
            bundle: Self.bundle,
            recordedBundleExists: recordedBundleExists,
            isInstalledLocation: Self.isInstalledLocation
        ) {
        case .none:
            break
        case .register:
            NSLog("Start at Login: bundle changed, re-registering the login item")
            register()
        case .enablePreference:
            store(enabled: true)
        case .disablePreference:
            store(enabled: false)
        }
    }

    enum ToggleOutcome {
        case changed
        /// The user revoked consent in System Settings; only they can restore
        /// it, so registering here would fail with kSMErrorLaunchDeniedByUser.
        case needsUserApproval
    }

    func toggle() -> ToggleOutcome {
        switch SMAppService.mainApp.status {
        case .enabled:
            unregister()
        case .requiresApproval:
            return .needsUserApproval
        default:
            register()
        }
        return .changed
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    // MARK: - Registration

    private func register() {
        do {
            // A stale registration left over from a previous bundle rejects a
            // plain register; SMAppService.h recommends unregistering first
            // whenever the executable has changed.
            if Self.status == .notFound {
                try? SMAppService.mainApp.unregister()
            }
            try SMAppService.mainApp.register()
            store(enabled: true)
        } catch {
            NSLog("Failed to enable Start at Login: \(error)")
            store(enabled: false)
        }
    }

    private func unregister() {
        do {
            try SMAppService.mainApp.unregister()
        } catch {
            NSLog("Failed to disable Start at Login: \(error)")
        }
        store(enabled: false)
    }

    // MARK: - Stored preference

    private var storedPreference: LoginItemPreference? {
        guard let enabled = defaults.object(forKey: DefaultsKey.enabled) as? Bool else { return nil }
        return LoginItemPreference(
            enabled: enabled,
            bundle: BundleIdentity(
                path: defaults.string(forKey: DefaultsKey.bundlePath) ?? "",
                version: defaults.string(forKey: DefaultsKey.bundleVersion) ?? ""
            )
        )
    }

    private func store(enabled: Bool) {
        defaults.set(enabled, forKey: DefaultsKey.enabled)
        defaults.set(Self.bundle.path, forKey: DefaultsKey.bundlePath)
        defaults.set(Self.bundle.version, forKey: DefaultsKey.bundleVersion)
    }

    private static var bundle: BundleIdentity {
        BundleIdentity(
            path: Bundle.main.bundlePath,
            version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        )
    }

    /// Whether the running bundle sits directly in an Applications directory
    /// (`/Applications`, `~/Applications`, and the network/developer variants).
    /// A build output or a copy still in Downloads must never be able to claim
    /// the login item away from the installed app.
    private static var isInstalledLocation: Bool {
        let parent = URL(fileURLWithPath: Bundle.main.bundlePath)
            .deletingLastPathComponent()
            .standardizedFileURL
        return FileManager.default
            .urls(for: .allApplicationsDirectory, in: .allDomainsMask)
            .contains { $0.standardizedFileURL == parent }
    }

    private static var status: LoginItemStatus {
        switch SMAppService.mainApp.status {
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notFound: return .notFound
        case .notRegistered: return .notRegistered
        @unknown default: return .notFound
        }
    }
}

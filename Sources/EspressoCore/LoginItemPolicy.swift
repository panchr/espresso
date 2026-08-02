import Foundation

/// Mirrors `SMAppService.Status`. Duplicated here so the policy stays testable:
/// ServiceManagement only reports meaningfully from a signed, installed bundle,
/// which a unit test run has no way to be.
public enum LoginItemStatus: Equatable {
    /// Never registered, or unregistered after having been registered.
    case notRegistered
    /// Registered and eligible to launch at login.
    case enabled
    /// Registered, but the user revoked consent in System Settings.
    case requiresApproval
    /// No such registration could be found.
    case notFound
}

/// Which copy of the app a login-item registration belongs to. The version is
/// part of it because an in-place upgrade replaces the bundle without moving it.
public struct BundleIdentity: Equatable {
    public var path: String
    public var version: String

    public init(path: String, version: String) {
        self.path = path
        self.version = version
    }
}

/// What the app last recorded about its own login-item registration.
public struct LoginItemPreference: Equatable {
    /// Whether the user asked Espresso to start at login.
    public var enabled: Bool
    /// The bundle `enabled` was recorded against.
    public var bundle: BundleIdentity

    public init(enabled: Bool, bundle: BundleIdentity) {
        self.enabled = enabled
        self.bundle = bundle
    }
}

public enum LoginItemAction: Equatable {
    case none
    /// Recreate a registration that the system no longer has.
    case register
    /// Record that the item is on, having been turned on outside the app.
    case enablePreference
    /// Record that the item is off, having been removed outside the app.
    case disablePreference
}

/// Decides what launching should do about the login-item registration.
///
/// The problem this exists to solve: Espresso is ad-hoc signed, so a replaced
/// bundle has no stable code-signing identity tying it to the old one, and
/// macOS can drop the registration when the app is upgraded or reinstalled.
/// Left alone, "Start at Login" silently stops working after an upgrade.
///
/// Two traps sit on the other side, and recording *which bundle* the preference
/// was stored against avoids both. Resurrecting an item the user deleted: same
/// bundle with a vanished registration means they removed it, so that is
/// honored rather than undone. Hijacking another copy's registration: a
/// different path that still has a bundle on disk means a second copy is
/// running, and it leaves the installed copy's login item alone.
public enum LoginItemPolicy {
    public static func action(
        preference: LoginItemPreference?,
        status: LoginItemStatus,
        bundle: BundleIdentity,
        recordedBundleExists: Bool
    ) -> LoginItemAction {
        switch status {
        case .enabled:
            let current = LoginItemPreference(enabled: true, bundle: bundle)
            return preference == current ? .none : .enablePreference

        // The user revoked consent, and registering again would only fail with
        // kSMErrorLaunchDeniedByUser. Their choice stands until they change it
        // in System Settings.
        case .requiresApproval:
            return .none

        case .notRegistered, .notFound:
            guard let preference, preference.enabled else { return .none }
            if preference.bundle == bundle { return .disablePreference }
            // Same location, new version: an in-place upgrade. Different
            // location with nothing left behind: the app was moved. Either way
            // this is the copy the preference was about.
            if preference.bundle.path == bundle.path { return .register }
            return recordedBundleExists ? .none : .register
        }
    }
}

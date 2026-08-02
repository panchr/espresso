import EspressoCore
import Foundation

func runLoginItemPolicyTests() {
    let installed = BundleIdentity(path: "/Applications/Espresso.app", version: "0.1.1")
    let previous = BundleIdentity(path: "/Applications/Espresso.app", version: "0.1")
    let elsewhere = BundleIdentity(path: "/Users/x/Applications/Espresso.app", version: "0.1")

    func action(
        _ preference: LoginItemPreference?,
        _ status: LoginItemStatus,
        recordedBundleExists: Bool = false,
        bundle: BundleIdentity = BundleIdentity(path: "/Applications/Espresso.app", version: "0.1.1"),
        isInstalledLocation: Bool = true
    ) -> LoginItemAction {
        LoginItemPolicy.action(
            preference: preference,
            status: status,
            bundle: bundle,
            recordedBundleExists: recordedBundleExists,
            isInstalledLocation: isInstalledLocation
        )
    }

    func preference(_ enabled: Bool, _ bundle: BundleIdentity) -> LoginItemPreference {
        LoginItemPreference(enabled: enabled, bundle: bundle)
    }

    test("does nothing when the item is on and already recorded") {
        let stored = preference(true, installed)
        expect(action(stored, .enabled) == .none, "got \(action(stored, .enabled))")
    }

    test("adopts an item enabled outside the app") {
        expect(action(nil, .enabled) == .enablePreference, "got \(action(nil, .enabled))")
    }

    test("restamps the identity when the item survived an upgrade") {
        let stored = preference(true, previous)
        expect(action(stored, .enabled) == .enablePreference, "got \(action(stored, .enabled))")
    }

    // The case the whole policy exists for: an upgrade replaced the ad-hoc
    // signed bundle in place, so macOS dropped the registration the user asked
    // for. Relaunching from /Applications has to put it back.
    test("re-registers after an in-place upgrade") {
        let stored = preference(true, previous)
        expect(action(stored, .notRegistered) == .register, "got \(action(stored, .notRegistered))")
        expect(action(stored, .notFound) == .register, "got \(action(stored, .notFound))")
    }

    test("re-registers when the app moved and left nothing behind") {
        let stored = preference(true, elsewhere)
        expect(action(stored, .notFound) == .register, "got \(action(stored, .notFound))")
    }

    // A dev build or a second download must not steal the installed copy's
    // login item, which would break the moment that copy is deleted.
    test("leaves another copy's registration alone") {
        let stored = preference(true, elsewhere)
        let result = action(stored, .notRegistered, recordedBundleExists: true)
        expect(result == .none, "got \(result)")
    }

    // The regression this guard exists for: `brew upgrade` deletes the old
    // bundle before writing the new one, and its "Reopening" step relaunched a
    // repo build inside that window. The recorded copy looked gone, so the
    // build read as a move and took the registration.
    test("a build outside an Applications directory never claims the item") {
        let repoBuild = BundleIdentity(path: "/Users/x/projects/espresso/Espresso.app", version: "dev")
        let stored = preference(true, installed)
        let result = action(stored, .notRegistered, bundle: repoBuild, isInstalledLocation: false)
        expect(result == .none, "got \(result)")
    }

    test("an uninstalled copy cannot claim it even mid-upgrade") {
        let downloaded = BundleIdentity(path: "/Users/x/Downloads/Espresso.app", version: "0.1.1")
        let stored = preference(true, previous)
        // recordedBundleExists: false is exactly the upgrade window.
        let result = action(stored, .notFound, bundle: downloaded, isInstalledLocation: false)
        expect(result == .none, "got \(result)")
    }

    test("a real move between Applications directories still re-registers") {
        let userApps = BundleIdentity(path: "/Users/x/Applications/Espresso.app", version: "0.1.1")
        let stored = preference(true, installed)
        let result = action(stored, .notFound, bundle: userApps, isInstalledLocation: true)
        expect(result == .register, "got \(result)")
    }

    // Never resurrect a login item the user deleted in System Settings.
    test("forgets the preference when the same bundle lost its registration") {
        let stored = preference(true, installed)
        expect(action(stored, .notRegistered) == .disablePreference, "got \(action(stored, .notRegistered))")
    }

    test("does nothing when the user never asked to start at login") {
        expect(action(nil, .notRegistered) == .none, "got \(action(nil, .notRegistered))")
        let off = preference(false, previous)
        expect(action(off, .notRegistered) == .none, "got \(action(off, .notRegistered))")
        expect(action(off, .notFound) == .none, "got \(action(off, .notFound))")
    }

    // Registering again would only fail with kSMErrorLaunchDeniedByUser.
    test("leaves revoked consent alone") {
        let stored = preference(true, previous)
        expect(action(stored, .requiresApproval) == .none, "got \(action(stored, .requiresApproval))")
        expect(action(nil, .requiresApproval) == .none, "got \(action(nil, .requiresApproval))")
    }
}

import EspressoCore
import Foundation

func runLoginItemPolicyTests() {
    let installed = BundleIdentity(path: "/Applications/Espresso.app", version: "0.1.1")
    let previous = BundleIdentity(path: "/Applications/Espresso.app", version: "0.1")
    let elsewhere = BundleIdentity(path: "/Users/x/Applications/Espresso.app", version: "0.1")

    func action(
        _ preference: LoginItemPreference?,
        _ status: LoginItemStatus,
        recordedBundleExists: Bool = false
    ) -> LoginItemAction {
        LoginItemPolicy.action(
            preference: preference,
            status: status,
            bundle: installed,
            recordedBundleExists: recordedBundleExists
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

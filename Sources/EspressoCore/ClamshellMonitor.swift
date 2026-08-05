import Foundation
import IOKit

/// Watches the laptop lid and reports the moment it closes.
///
/// The lid state lives on `IOPMrootDomain` as `AppleClamshellState`. Only
/// machines with a lid publish it, so its absence is the supported way to ask
/// "does this Mac have a clamshell at all?" — desktops report `unsupported`
/// and the monitor stays inert rather than guessing.
///
/// Changes arrive as IOKit general-interest messages on the same registry
/// entry. The property is re-read on every message rather than filtering for
/// `kIOPMMessageClamshellStateChange`: that constant is a nested C macro that
/// Swift does not import, and a registry read is cheap enough that recomputing
/// on unrelated power messages costs nothing.
public final class ClamshellMonitor {
    public enum State: Equatable {
        /// This Mac does not report a lid state.
        case unsupported
        case open
        case closed
    }

    /// Called on the main thread when the lid goes from open to closed.
    public var onClose: (() -> Void)?

    public private(set) var state: State

    /// Reads the current lid state: true when closed, nil when unavailable.
    /// Injectable so tests can drive transitions without hardware.
    private let readLidClosed: () -> Bool?
    private var notificationPort: IONotificationPortRef?
    private var interest: io_object_t = IO_OBJECT_NULL
    private var rootDomain: io_service_t = IO_OBJECT_NULL

    /// Passing a reader overrides the registry lookup; tests use it to drive
    /// transitions on hardware whose lid they cannot touch.
    public init(readLidClosed: (() -> Bool?)? = nil) {
        let read = readLidClosed ?? Self.readRegistryLidState
        self.readLidClosed = read
        state = Self.state(from: read())
    }

    deinit {
        if interest != IO_OBJECT_NULL { IOObjectRelease(interest) }
        if rootDomain != IO_OBJECT_NULL { IOObjectRelease(rootDomain) }
        if let notificationPort { IONotificationPortDestroy(notificationPort) }
    }

    public var isSupported: Bool {
        state != .unsupported
    }

    /// Subscribes to lid-state changes. A no-op on hardware without a lid, so
    /// callers don't have to branch on availability themselves.
    public func start() {
        guard isSupported, notificationPort == nil else { return }

        rootDomain = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard rootDomain != IO_OBJECT_NULL else {
            NSLog("Clamshell: IOPMrootDomain unavailable, lid changes will not be observed")
            return
        }

        let port = IONotificationPortCreate(kIOMainPortDefault)
        // Delivering on the main queue keeps onClose on the thread that owns
        // the UI and the caffeinate child, matching the rest of the app.
        IONotificationPortSetDispatchQueue(port, DispatchQueue.main)

        let callback: IOServiceInterestCallback = { context, _, _, _ in
            guard let context else { return }
            Unmanaged<ClamshellMonitor>.fromOpaque(context).takeUnretainedValue().refresh()
        }
        let result = IOServiceAddInterestNotification(
            port,
            rootDomain,
            kIOGeneralInterest,
            callback,
            Unmanaged.passUnretained(self).toOpaque(),
            &interest
        )
        guard result == KERN_SUCCESS else {
            NSLog("Clamshell: failed to observe lid changes (0x\(String(result, radix: 16)))")
            IONotificationPortDestroy(port)
            return
        }
        notificationPort = port
    }

    /// Re-reads the lid state and reports an open-to-closed transition.
    /// Only the transition fires `onClose`: a lid that was already shut when
    /// the app launched is not the user "entering" clamshell mode.
    public func refresh() {
        let previous = state
        state = Self.state(from: readLidClosed())
        guard previous == .open, state == .closed else { return }
        onClose?()
    }

    private static func state(from lidClosed: Bool?) -> State {
        guard let lidClosed else { return .unsupported }
        return lidClosed ? .closed : .open
    }

    private static func readRegistryLidState() -> Bool? {
        let rootDomain = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard rootDomain != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(rootDomain) }

        let property = IORegistryEntryCreateCFProperty(
            rootDomain,
            "AppleClamshellState" as CFString,
            kCFAllocatorDefault,
            0
        )
        return property?.takeRetainedValue() as? Bool
    }
}

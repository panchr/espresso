import Foundation

/// Manages a single `caffeinate` child process that keeps the Mac awake.
public final class CaffeinateController {
    /// End of the current session, or nil when running indefinitely.
    public private(set) var endDate: Date?
    /// Called on the main thread when the child exits on its own (timer expired).
    public var onExpire: (() -> Void)?

    private let executableURL: URL
    private var process: Process?

    /// The executable is injectable so tests can substitute a stub for caffeinate.
    public init(executableURL: URL = URL(fileURLWithPath: "/usr/bin/caffeinate")) {
        self.executableURL = executableURL
    }

    public var isActive: Bool {
        process != nil
    }

    /// Identifier of the running child, exposed for tests and diagnostics.
    public var processIdentifier: Int32? {
        process?.processIdentifier
    }

    /// Starts keeping the Mac awake, replacing any running session.
    /// A nil duration keeps the Mac awake until cancelled.
    public func start(duration: TimeInterval?) {
        stop()

        let process = Process()
        process.executableURL = executableURL
        // -d prevents display sleep, -i prevents idle system sleep. -w ties the
        // child's lifetime to ours so even an uncleanly killed app (SIGTERM,
        // crash) can't leave an orphaned wake-lock; -t still applies first if
        // sooner — caffeinate exits on whichever fires.
        var arguments = ["-di", "-w", String(ProcessInfo.processInfo.processIdentifier)]
        if let duration {
            arguments += ["-t", String(Int(duration))]
        }
        process.arguments = arguments
        process.terminationHandler = { [weak self] finished in
            DispatchQueue.main.async {
                guard let self, self.process === finished else { return }
                self.process = nil
                self.endDate = nil
                self.onExpire?()
            }
        }

        do {
            try process.run()
        } catch {
            NSLog("Failed to launch caffeinate: \(error)")
            return
        }

        self.process = process
        endDate = duration.map { Date().addingTimeInterval($0) }
    }

    public func stop() {
        // Detach the handler so a cancellation isn't reported as an expiry.
        process?.terminationHandler = nil
        process?.terminate()
        process = nil
        endDate = nil
    }
}

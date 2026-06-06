import Foundation

/// Manages a single `caffeinate` child process that keeps the Mac awake.
final class CaffeinateController {
    /// End of the current session, or nil when running indefinitely.
    private(set) var endDate: Date?
    /// Called on the main thread when `caffeinate` exits on its own (timer expired).
    var onExpire: (() -> Void)?

    private var process: Process?

    var isActive: Bool {
        process != nil
    }

    /// Starts keeping the Mac awake, replacing any running session.
    /// A nil duration keeps the Mac awake until cancelled.
    func start(duration: TimeInterval?) {
        stop()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        // -d prevents display sleep, -i prevents idle system sleep.
        var arguments = ["-di"]
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

    func stop() {
        // Detach the handler so a cancellation isn't reported as an expiry.
        process?.terminationHandler = nil
        process?.terminate()
        process = nil
        endDate = nil
    }
}

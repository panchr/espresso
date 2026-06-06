import EspressoCore
import Foundation

func runCaffeinateControllerTests() {
    let stubDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("espresso-tests-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: stubDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: stubDirectory) }

    /// Writes an executable shell script that stands in for caffeinate, so
    /// tests never hold real power assertions.
    func stub(_ script: String) throws -> URL {
        let url = stubDirectory.appendingPathComponent(UUID().uuidString)
        try "#!/bin/sh\n\(script)\n".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    func childExited(_ pid: Int32) -> Bool {
        eventually { kill(pid, 0) != 0 }
    }

    test("timed session sets endDate") {
        let controller = CaffeinateController(executableURL: try stub("exec /bin/sleep 60"))
        controller.start(duration: 120)
        defer { controller.stop() }

        expect(controller.isActive, "controller should be active")
        let endDate = try require(controller.endDate, "endDate should be set")
        expect(abs(endDate.timeIntervalSinceNow - 120) < 5, "endDate should be ~120s out")
    }

    test("indefinite session has no endDate") {
        let controller = CaffeinateController(executableURL: try stub("exec /bin/sleep 60"))
        controller.start(duration: nil)
        defer { controller.stop() }

        expect(controller.isActive, "controller should be active")
        expect(controller.endDate == nil, "indefinite session should have no endDate")
    }

    test("stop terminates child without reporting expiry") {
        let controller = CaffeinateController(executableURL: try stub("exec /bin/sleep 60"))
        var expiries = 0
        controller.onExpire = { expiries += 1 }

        controller.start(duration: nil)
        let pid = try require(controller.processIdentifier, "child should be running")
        controller.stop()

        expect(!controller.isActive, "controller should be inactive after stop")
        expect(controller.endDate == nil, "endDate should be cleared")
        expect(childExited(pid), "child should be terminated by stop()")
        settle()
        expect(expiries == 0, "cancellation must not be reported as expiry")
    }

    test("natural exit fires onExpire and resets") {
        let controller = CaffeinateController(executableURL: try stub("exit 0"))
        var expiries = 0
        controller.onExpire = { expiries += 1 }

        controller.start(duration: 1)
        expect(eventually { expiries == 1 }, "onExpire should fire when the child exits on its own")
        expect(!controller.isActive, "controller should reset after expiry")
        expect(controller.endDate == nil, "endDate should be cleared after expiry")
    }

    test("restart replaces child without reporting expiry") {
        let controller = CaffeinateController(executableURL: try stub("exec /bin/sleep 60"))
        var expiries = 0
        controller.onExpire = { expiries += 1 }

        controller.start(duration: nil)
        let firstPid = try require(controller.processIdentifier, "first child should be running")
        controller.start(duration: 60)
        defer { controller.stop() }
        let secondPid = try require(controller.processIdentifier, "second child should be running")

        expect(firstPid != secondPid, "restart should spawn a new child")
        expect(childExited(firstPid), "old child should be terminated on restart")
        expect(controller.isActive, "controller should stay active across restart")
        expect(controller.endDate != nil, "timed restart should set endDate")
        settle()
        expect(expiries == 0, "replacing a session must not be reported as expiry")
    }

    test("stop without start is harmless") {
        let controller = CaffeinateController()
        controller.stop()
        expect(!controller.isActive, "controller should be inactive")
        expect(controller.endDate == nil, "endDate should be nil")
    }
}

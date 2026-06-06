import Foundation

/// Minimal test harness: CLT-only toolchains can't run XCTest or Swift
/// Testing, so tests are plain functions executed by this runner.
var testFailures = 0

func test(_ name: String, _ body: () throws -> Void) {
    let failuresBefore = testFailures
    do {
        try body()
    } catch {
        testFailures += 1
        print("  threw: \(error)")
    }
    print(testFailures == failuresBefore ? "PASS \(name)" : "FAIL \(name)")
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
    if !condition() {
        testFailures += 1
        print("  \(file):\(line): \(message)")
    }
}

struct RequireError: Error {
    let message: String
}

func require<T>(_ value: T?, _ message: String) throws -> T {
    guard let value else { throw RequireError(message: message) }
    return value
}

/// Polls until the condition holds or the timeout elapses, pumping the main
/// run loop so main-queue callbacks (like CaffeinateController.onExpire) run.
func eventually(timeout: TimeInterval = 2, _ condition: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
    }
    return condition()
}

/// Pumps the main run loop briefly, giving stray callbacks a chance to fire.
func settle(_ seconds: TimeInterval = 0.3) {
    RunLoop.main.run(until: Date().addingTimeInterval(seconds))
}

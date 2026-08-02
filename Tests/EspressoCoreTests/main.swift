import Foundation

runCountdownTests()
runCaffeinateControllerTests()
runLoginItemPolicyTests()

if testFailures > 0 {
    print("\n\(testFailures) failure(s)")
    exit(1)
}
print("\nAll tests passed")

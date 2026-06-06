// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Espresso",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "EspressoCore",
            path: "Sources/EspressoCore"
        ),
        .executableTarget(
            name: "Espresso",
            dependencies: ["EspressoCore"],
            path: "Sources/Espresso"
        ),
        // A plain executable rather than a .testTarget: Command Line Tools
        // (without Xcode) can't run .xctest bundles and their Swift Testing
        // runner is incomplete, so tests use a minimal self-contained harness.
        .executableTarget(
            name: "EspressoCoreTests",
            dependencies: ["EspressoCore"],
            path: "Tests/EspressoCoreTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)

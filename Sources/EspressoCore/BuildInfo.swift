import Foundation

/// Formats the build identity shown under the app name in the menu.
public enum BuildInfo {
    private static let unstamped = "0.0.0"
    private static let unknownCommit = "unknown"

    /// The version line, e.g. `v0.1.1 (a1b2c3d4)`.
    ///
    /// Untagged builds stamp the short commit as the version, which would
    /// otherwise print the same hash twice; those are labelled `dev` instead so
    /// the line always answers "release or not" at a glance.
    public static func versionLine(version: String, commit: String) -> String {
        let version = version.trimmingCharacters(in: .whitespacesAndNewlines)
        let commit = commit.trimmingCharacters(in: .whitespacesAndNewlines)

        let hasCommit = !commit.isEmpty && commit != unknownCommit
        let isRelease = !version.isEmpty
            && version != unstamped
            && !(hasCommit && commit.hasPrefix(version))

        switch (isRelease, hasCommit) {
        case (true, true): return "v\(version) (\(commit))"
        case (true, false): return "v\(version)"
        case (false, true): return "dev (\(commit))"
        case (false, false): return "unknown version"
        }
    }
}

import EspressoCore
import Foundation

func runBuildInfoTests() {
    func line(_ version: String, _ commit: String) -> String {
        BuildInfo.versionLine(version: version, commit: commit)
    }

    test("names a tagged release and its commit") {
        expect(line("0.1.1", "a1b2c3d4") == "v0.1.1 (a1b2c3d4)", "got \(line("0.1.1", "a1b2c3d4"))")
    }

    // `make app` outside a tag stamps the short SHA as the version, so the
    // hash would otherwise appear twice on one line.
    test("labels an untagged build dev rather than repeating the hash") {
        expect(line("ad33624", "ad33624a") == "dev (ad33624a)", "got \(line("ad33624", "ad33624a"))")
    }

    test("treats the unstamped placeholder as a dev build") {
        expect(line("0.0.0", "a1b2c3d4") == "dev (a1b2c3d4)", "got \(line("0.0.0", "a1b2c3d4"))")
    }

    // Building from a source tarball leaves no git repo to read a SHA from.
    test("omits the commit when there is none") {
        expect(line("0.1.1", "") == "v0.1.1", "got \(line("0.1.1", ""))")
        expect(line("0.1.1", "unknown") == "v0.1.1", "got \(line("0.1.1", "unknown"))")
    }

    test("falls back when nothing was stamped") {
        expect(line("", "") == "unknown version", "got \(line("", ""))")
        expect(line("0.0.0", "unknown") == "unknown version", "got \(line("0.0.0", "unknown"))")
    }

    test("ignores surrounding whitespace") {
        expect(line(" 0.1.1 ", " a1b2c3d4\n") == "v0.1.1 (a1b2c3d4)", "got \(line(" 0.1.1 ", " a1b2c3d4\n"))")
    }
}

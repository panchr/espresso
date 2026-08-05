import EspressoCore
import Foundation

func runClamshellMonitorTests() {
    /// Drives the monitor from a lid state the test controls.
    func monitor(startingClosed: Bool?) -> (ClamshellMonitor, (Bool?) -> Void) {
        var lidClosed = startingClosed
        let monitor = ClamshellMonitor(readLidClosed: { lidClosed })
        return (monitor, { lidClosed = $0 })
    }

    test("reports the lid state at construction") {
        expect(ClamshellMonitor(readLidClosed: { false }).state == .open, "an open lid reads as open")
        expect(ClamshellMonitor(readLidClosed: { true }).state == .closed, "a closed lid reads as closed")
    }

    test("hardware without a lid is unsupported") {
        let monitor = ClamshellMonitor(readLidClosed: { nil })
        expect(monitor.state == .unsupported, "a missing lid state is unsupported")
        expect(!monitor.isSupported, "unsupported hardware reports isSupported false")
    }

    test("closing the lid fires onClose") {
        let (monitor, setLid) = monitor(startingClosed: false)
        var closes = 0
        monitor.onClose = { closes += 1 }

        setLid(true)
        monitor.refresh()

        expect(closes == 1, "closing the lid reported once, got \(closes)")
        expect(monitor.state == .closed, "state follows the lid")
    }

    test("opening the lid does not fire onClose") {
        let (monitor, setLid) = monitor(startingClosed: true)
        var closes = 0
        monitor.onClose = { closes += 1 }

        setLid(false)
        monitor.refresh()

        expect(closes == 0, "opening the lid must not report a close")
        expect(monitor.state == .open, "state follows the lid")
    }

    // Unrelated power messages also wake the callback, so a re-read that finds
    // no change must stay quiet rather than stopping the session repeatedly.
    test("an unchanged closed lid fires onClose only once") {
        let (monitor, setLid) = monitor(startingClosed: false)
        var closes = 0
        monitor.onClose = { closes += 1 }

        setLid(true)
        monitor.refresh()
        monitor.refresh()
        monitor.refresh()

        expect(closes == 1, "only the transition counts, got \(closes)")
    }

    test("reclosing the lid fires again") {
        let (monitor, setLid) = monitor(startingClosed: false)
        var closes = 0
        monitor.onClose = { closes += 1 }

        setLid(true)
        monitor.refresh()
        setLid(false)
        monitor.refresh()
        setLid(true)
        monitor.refresh()

        expect(closes == 2, "each open-to-closed transition counts, got \(closes)")
    }

    // Launching with the lid already shut is not the user closing it, and
    // stopping a session they just started would be wrong.
    test("a lid already closed at launch does not fire") {
        let (monitor, _) = monitor(startingClosed: true)
        var closes = 0
        monitor.onClose = { closes += 1 }

        monitor.refresh()

        expect(closes == 0, "no transition happened, got \(closes)")
    }

    test("unsupported hardware never fires") {
        let (monitor, setLid) = monitor(startingClosed: nil)
        var closes = 0
        monitor.onClose = { closes += 1 }

        monitor.refresh()
        // Even if the property were to appear later, there is no open state to
        // transition from, so nothing is reported.
        setLid(true)
        monitor.refresh()

        expect(closes == 0, "unsupported hardware stays silent, got \(closes)")
    }

    test("start is harmless on unsupported hardware") {
        let monitor = ClamshellMonitor(readLidClosed: { nil })
        monitor.start()
        expect(monitor.state == .unsupported, "start must not change an unsupported state")
    }
}

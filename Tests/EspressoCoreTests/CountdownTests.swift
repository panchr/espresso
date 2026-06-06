import EspressoCore
import Foundation

func runCountdownTests() {
    test("formats hours as H:MM:SS") {
        expect(Countdown.text(remaining: 3723) == "1:02:03", "got \(Countdown.text(remaining: 3723))")
    }

    test("formats sub-hour as M:SS") {
        expect(Countdown.text(remaining: 3572) == "59:32", "got \(Countdown.text(remaining: 3572))")
    }

    test("formats sub-minute") {
        expect(Countdown.text(remaining: 45) == "0:45", "got \(Countdown.text(remaining: 45))")
    }

    test("clamps negative to zero") {
        expect(Countdown.text(remaining: -5) == "0:00", "got \(Countdown.text(remaining: -5))")
    }

    test("rounds fractional seconds up") {
        expect(Countdown.text(remaining: 89.2) == "1:30", "got \(Countdown.text(remaining: 89.2))")
    }
}

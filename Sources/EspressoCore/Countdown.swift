import Foundation

public enum Countdown {
    /// Formats a remaining interval as H:MM:SS (or M:SS under an hour),
    /// rounding up and clamping at zero.
    public static func text(remaining: TimeInterval) -> String {
        let total = max(0, Int(remaining.rounded(.up)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

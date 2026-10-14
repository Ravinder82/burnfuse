import Foundation

/// Compact, human relative time for footers and logs.
public enum RelativeTime {
    public static func short(_ date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 10 { return "just now" }
        if seconds < 60 { return "\(Int(seconds))s ago" }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        return "\(hours / 24)d ago"
    }
}
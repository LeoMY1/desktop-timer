import Foundation

public protocol TimeSource: AnyObject { var now: Date { get } }

/// ContinuousClock includes system sleep; UI timer callbacks are only refresh triggers.
public final class ContinuousTimeSource: TimeSource {
    private let clock = ContinuousClock()
    private let instant: ContinuousClock.Instant
    private let anchor: Date
    public init() { anchor = Date(); instant = clock.now }
    public var now: Date {
        let value = instant.duration(to: clock.now).components
        return anchor.addingTimeInterval(Double(value.seconds) + Double(value.attoseconds) / 1e18)
    }
}

public enum StudyDate {
    public static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }
    public static func day(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }
    public static func nextMidnight(_ date: Date) -> Date {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!
    }
    public static func clock(_ date: Date) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour!, parts.minute!)
    }
    public static func timer(_ seconds: Double) -> String {
        let minutes = Int(max(0, seconds) / 60)
        return String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
    public static func duration(_ seconds: Double) -> String {
        let minutes = Int(max(0, seconds) / 60)
        if minutes == 0 { return seconds > 0 ? "不足1分钟" : "0分钟" }
        if minutes < 60 { return "\(minutes)分钟" }
        return minutes % 60 == 0 ? "\(minutes / 60)小时" : "\(minutes / 60)小时\(minutes % 60)分钟"
    }
}

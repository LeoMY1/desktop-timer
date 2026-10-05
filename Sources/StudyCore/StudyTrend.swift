import Foundation

public enum StudyPeriodKind: String, CaseIterable, Identifiable {
    case week, month
    public var id: String { rawValue }
    public var title: String { self == .week ? "周" : "月" }
}

/// Calendar dates use the same time zone as the ledger, regardless of host settings.
public extension StudyDate {
    static func date(for day: String) -> Date? {
        let parts = day.split(separator: "-")
        guard day.count == 10, parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let number = Int(parts[2]),
              let date = calendar.date(from: DateComponents(year: year, month: month, day: number)),
              Self.day(date) == day else { return nil }
        return date
    }
}

public struct StudyPeriod: Identifiable, Equatable {
    public let kind: StudyPeriodKind
    public let start: Date
    public let end: Date // Exclusive: next Monday or first day of the next month.
    public var id: String { kind.rawValue + ":" + StudyDate.day(start) }

    public init(containing date: Date, kind: StudyPeriodKind) {
        self.kind = kind
        let calendar = StudyDate.calendar
        let day = calendar.startOfDay(for: date)
        switch kind {
        case .week:
            let offset = (calendar.component(.weekday, from: day) + 5) % 7
            start = calendar.date(byAdding: .day, value: -offset, to: day)!
            end = calendar.date(byAdding: .day, value: 7, to: start)!
        case .month:
            start = calendar.date(from: calendar.dateComponents([.year, .month], from: day))!
            end = calendar.date(byAdding: .month, value: 1, to: start)!
        }
    }

    public var lastDay: Date { StudyDate.calendar.date(byAdding: .day, value: -1, to: end)! }
    public var year: Int { StudyDate.calendar.component(.year, from: start) }
    public func contains(_ date: Date) -> Bool { date >= start && date < end }
    public var days: [Date] {
        let calendar = StudyDate.calendar
        var result: [Date] = []
        var day = start
        while day < end {
            result.append(day)
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return result
    }
}

public struct StudyDayTotal: Identifiable, Equatable {
    public let date: Date
    public let seconds: Double? // nil is a future date; zero is an observed date without time.
    public var id: String { StudyDate.day(date) }
}

/// Read-only statistics derived from valid intervals, never from notes or reminder entries.
public struct StudyTrendSnapshot {
    public let today: Date
    public let firstDay: Date
    public let totalsByDay: [String: Double]

    public init(ledger: Ledger) {
        let calendar = StudyDate.calendar
        today = calendar.startOfDay(for: ledger.checkpointAt)
        firstDay = min(today, ledger.sessions.map { calendar.startOfDay(for: $0.startedAt) }.min() ?? today)
        totalsByDay = ledger.sessions.reduce(into: [:]) { totals, session in
            totals[session.day, default: 0] += session.seconds
        }
    }

    public func days(in period: StudyPeriod) -> [StudyDayTotal] {
        period.days.map { date in
            StudyDayTotal(date: date, seconds: date > today ? nil : totalsByDay[StudyDate.day(date), default: 0])
        }
    }

    public func total(in period: StudyPeriod) -> Double {
        days(in: period).reduce(0) { $0 + ($1.seconds ?? 0) }
    }

    public func periods(of kind: StudyPeriodKind, including selection: StudyPeriod? = nil) -> [StudyPeriod] {
        let current = StudyPeriod(containing: today, kind: kind)
        var earliest = StudyPeriod(containing: firstDay, kind: kind).start
        if let selection = selection, selection.kind == kind, selection.start <= current.start {
            earliest = min(earliest, selection.start)
        }
        var result: [StudyPeriod] = []
        var period = current
        while period.start >= earliest {
            result.append(period)
            let previousDay = StudyDate.calendar.date(byAdding: .day, value: -1, to: period.start)!
            period = StudyPeriod(containing: previousDay, kind: kind)
        }
        return result
    }
}

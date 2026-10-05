import SwiftUI
import StudyCore

enum HistorySection: String, CaseIterable, Identifiable {
    case daily, trend
    var id: String { rawValue }
    var title: String { self == .daily ? "每日记录" : "学习趋势" }
}

/// Owned by the history window; browsing does not change the timer or persistent ledger.
final class HistoryNavigation: ObservableObject {
    @Published private(set) var section: HistorySection = .daily
    @Published private(set) var recordDay: String?
    @Published private(set) var trendDay: String?
    @Published var periodKind: StudyPeriodKind = .week

    func dailyDate(today: String) -> String { recordDay ?? today }
    func trendDate(today: String) -> String { trendDay ?? today }

    func selectSection(_ section: HistorySection, today: String) {
        if section == .trend, trendDay == nil { trendDay = today }
        self.section = section
    }

    func selectRecord(_ day: String) { recordDay = day }

    func selectTrendDay(_ day: String, today: String) {
        guard day <= today, StudyDate.date(for: day) != nil else { return }
        trendDay = day
    }

    func selectPeriod(_ period: StudyPeriod, today: Date) {
        guard period.start <= today else { return }
        trendDay = StudyDate.day(period.contains(today) ? today : period.lastDay)
    }

    func moveTrendDay(by offset: Int, today: Date) {
        let selected = trendDate(today: StudyDate.day(today))
        let period = StudyPeriod(containing: StudyDate.date(for: selected) ?? today, kind: periodKind)
        let days = period.days.filter { $0 <= today }.map(StudyDate.day)
        guard !days.isEmpty else { return }
        let current = days.firstIndex(of: selected) ?? 0
        trendDay = days[min(max(0, current + offset), days.count - 1)]
    }

    func openTrendRecord(today: String) {
        recordDay = trendDate(today: today)
        section = .daily
    }
}

extension StudyPeriod {
    var sidebarTitle: String {
        if kind == .month { return "\(StudyDate.calendar.component(.month, from: start))月" }
        return shortDate(start) + "–" + shortDate(lastDay)
    }
    var rangeTitle: String {
        if kind == .month { return "\(year)年\(StudyDate.calendar.component(.month, from: start))月" }
        let first = StudyDate.day(start).replacingOccurrences(of: "-", with: "/")
        let last = StudyDate.calendar.component(.year, from: lastDay) == year
            ? shortDate(lastDay) : StudyDate.day(lastDay).replacingOccurrences(of: "-", with: "/")
        return first + " – " + last
    }
    private func shortDate(_ date: Date) -> String {
        String(StudyDate.day(date).suffix(5)).replacingOccurrences(of: "-", with: "/")
    }
}

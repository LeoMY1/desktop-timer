#if INTERNAL_TESTING
import AppKit
import SwiftUI
import StudyCore

extension AppDelegate {
    /// Integration and render checks use their own clock, model, window and SQLite directory.
    func runTrendUICheck(output: URL, check: (String, Bool) -> Void) throws {
        let clock = UICheckClock()
        clock.now = StudyDate.date(for: "2026-09-01")!.addingTimeInterval(9 * 3600)
        let dataDirectory = output.appendingPathComponent("trend-data-" + UUID().uuidString)
        let store = try SQLiteLedgerStore(directory: dataDirectory, now: clock.now)
        let controller = try StudyController(source: clock, store: store)
        let minutes = [145,195,0,270,325,220,180,285,310,120,0,345,280,260,190,235,305,175,360,0,225,275,320,185,245,285,170,210,315,245]
        for (index, duration) in minutes.enumerated() {
            let day = String(format: "2026-09-%02d", index + 1)
            clock.now = StudyDate.date(for: day)!.addingTimeInterval(9 * 3600)
            if duration > 0 {
                try controller.perform(.start); clock.add(Double(duration * 60)); try controller.perform(.stop)
            } else { controller.tick() }
        }
        for (day, duration) in [("2026-10-01",380),("2026-10-02",0),("2026-10-03",270),("2026-10-04",345),("2026-10-05",85)] {
            clock.now = StudyDate.date(for: day)!.addingTimeInterval(9 * 3600)
            if duration > 0 {
                try controller.perform(.start); clock.add(Double(duration * 60)); try controller.perform(.stop)
            } else { controller.tick() }
        }
        try controller.perform(.quit)
        let model = StudyModel()
        model.source = clock; model.controller = controller; model.ready = true; model.refresh()
        let navigation = HistoryNavigation()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 850, height: 620),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "学习记录 · 隔离检查"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: HistoryView(model: model, navigation: navigation, showTail: { _ in }, deleteRecord: { _ = model.deleteRecord($0) }))
        window.center(); window.orderFrontRegardless()
        let appearance = NSApp.appearance
        defer { window.close(); NSApp.appearance = appearance }
        func capture(_ name: String) {
            RunLoop.current.run(until: Date().addingTimeInterval(0.65))
            window.contentView?.layoutSubtreeIfNeeded()
            guard let view = window.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            try? bitmap.representation(using: .png, properties: [:])?.write(to: output.appendingPathComponent(name))
        }

        let today = model.ledger.day, before = model.ledger
        check("history_initial_daily_today", navigation.section == .daily && navigation.dailyDate(today: today) == today)
        navigation.selectRecord("2026-09-29")
        navigation.selectSection(.trend, today: today)
        check("trend_first_visit_current_week", navigation.periodKind == .week && navigation.trendDate(today: today) == today)
        let selectedPeriod = StudyPeriod(containing: StudyDate.date(for: "2026-09-30")!, kind: .week)
        navigation.selectPeriod(selectedPeriod, today: clock.now)
        check("trend_historical_period_selects_last_day", navigation.trendDay == "2026-10-04")
        navigation.selectTrendDay("2026-09-30", today: today)
        navigation.selectSection(.daily, today: today)
        check("history_preserves_daily_selection", navigation.dailyDate(today: today) == "2026-09-29")
        navigation.selectSection(.trend, today: today)
        check("trend_preserves_its_selection", navigation.trendDate(today: today) == "2026-09-30")
        navigation.periodKind = .month
        check("trend_switch_month_anchors_selected_day", StudyPeriod(containing: StudyDate.date(for: navigation.trendDay!)!, kind: navigation.periodKind).rangeTitle == "2026年9月")
        navigation.periodKind = .week
        for (name, theme) in [("light", NSAppearance.Name.aqua), ("dark", NSAppearance.Name.darkAqua)] {
            NSApp.appearance = NSAppearance(named: theme)
            capture("\(name)-trend-week.png")
            navigation.periodKind = .month
            capture("\(name)-trend-month.png")
            navigation.periodKind = .week
        }
        NSApp.appearance = NSAppearance(named: .aqua)
        window.setContentSize(NSSize(width: 760, height: 560))
        capture("light-trend-minimum.png")
        check("trend_renders_minimum_window", window.contentView!.bounds.width == 760 && window.contentView!.bounds.height == 560)
        window.setContentSize(NSSize(width: 850, height: 620))
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        func inputView(in view: NSView) -> TrendChartInputView? {
            if let input = view as? TrendChartInputView { return input }
            return view.subviews.lazy.compactMap { inputView(in: $0) }.first
        }
        if let input = inputView(in: window.contentView!) {
            let point = input.convert(NSPoint(x: input.bounds.midX, y: input.bounds.midY), to: nil)
            let hover = NSEvent.mouseEvent(with: .mouseMoved, location: point, modifierFlags: [], timestamp: 0,
                                          windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 0, pressure: 0)!
            input.mouseMoved(with: hover)
            capture("light-trend-hover.png")
            input.mouseExited(with: hover)
            let click = NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [], timestamp: 0,
                                          windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
            input.mouseDown(with: click)
            check("trend_native_click_selects_date_and_focus", navigation.trendDay == "2026-10-01" && window.firstResponder === input)
            for (key, expected, name) in [(UInt16(123), "2026-09-30", "left"), (UInt16(124), "2026-10-01", "right")] {
                let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                             windowNumber: window.windowNumber, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: key)!
                input.keyDown(with: event)
                RunLoop.current.run(until: Date().addingTimeInterval(0.05))
                check("trend_native_arrow_" + name, navigation.trendDay == expected && navigation.section == .trend)
            }
        } else {
            check("trend_native_click_selects_date_and_focus", false)
            check("trend_native_arrow_left", false)
            check("trend_native_arrow_right", false)
        }
        navigation.selectTrendDay("2026-10-02", today: today)
        check("trend_zero_day_selection_stays_in_trend", navigation.section == .trend && navigation.trendDay == "2026-10-02" && model.ledger.total(on: "2026-10-02") == 0)
        navigation.openTrendRecord(today: today)
        check("trend_open_record_selects_empty_day", navigation.section == .daily && navigation.recordDay == "2026-10-02")
        capture("trend-empty-day-records.png")
        navigation.selectSection(.trend, today: today)
        check("trend_return_from_records_keeps_period", navigation.trendDay == "2026-10-02" && navigation.periodKind == .week)
        navigation.selectTrendDay("2026-10-06", today: today)
        check("trend_future_day_rejected", navigation.trendDay == "2026-10-02")
        let saved = try store.load()
        check("trend_browsing_preserves_ledger_and_disk", model.ledger == before && saved == before)

        navigation.selectPeriod(StudyPeriod(containing: clock.now, kind: .week), today: clock.now)
        check("trend_return_current_selects_today", navigation.trendDay == today)
        capture("trend-current-week-future.png")
        _ = model.perform(.start); clock.add(3.25); model.tick()
        let snapshot = StudyTrendSnapshot(ledger: model.ledger)
        check("trend_live_model_refresh_matches_daily_total", snapshot.totalsByDay[today] == 5103.25 && model.phase == .running)
        _ = model.perform(.pause); clock.add(60); model.tick()
        check("trend_pause_freezes_total", StudyTrendSnapshot(ledger: model.ledger).totalsByDay[today] == 5103.25)
        navigation.selectTrendDay("2026-09-30", today: today)
        let target = model.ledger.sessions.first { $0.day == "2026-09-30" }!.id
        let oldMonthTotal = StudyTrendSnapshot(ledger: model.ledger).total(in: StudyPeriod(containing: StudyDate.date(for: "2026-09-30")!, kind: .month))
        check("trend_delete_history_succeeds", model.deleteRecord(.session(target)))
        let after = StudyTrendSnapshot(ledger: model.ledger)
        check("trend_delete_updates_total_preserves_selection", after.totalsByDay["2026-09-30", default: 0] == 0 && navigation.trendDay == "2026-09-30" && after.total(in: StudyPeriod(containing: StudyDate.date(for: "2026-09-30")!, kind: .month)) == oldMonthTotal - 245 * 60)
        model.ready = false; model.errorText = "隔离检查：学习记录无法读取"
        capture("trend-load-error.png")
        model.ready = true; model.errorText = nil
        _ = model.perform(.quit)
    }
}
#endif

import SwiftUI
import Charts
import StudyCore

struct StudyTrendView: View {
    let snapshot: StudyTrendSnapshot
    @ObservedObject var navigation: HistoryNavigation
    let errorText: String?

    private var today: String { StudyDate.day(snapshot.today) }
    private var selectedDay: String { navigation.trendDate(today: today) }
    private var period: StudyPeriod {
        StudyPeriod(containing: StudyDate.date(for: selectedDay) ?? snapshot.today, kind: navigation.periodKind)
    }

    var body: some View {
        let days = snapshot.days(in: period)
        let total = snapshot.total(in: period)
        let isCurrent = period.contains(snapshot.today)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("学习趋势").font(.system(size: 24, weight: .semibold))
                        Spacer()
                        Picker("趋势周期", selection: $navigation.periodKind) {
                            ForEach(StudyPeriodKind.allCases) { kind in Text(kind.title).tag(kind) }
                        }
                        .pickerStyle(.segmented).labelsHidden().frame(width: 104)
                        .accessibilityIdentifier("trend-period-picker")
                    }
                    HStack {
                        Text(period.rangeTitle).font(.system(size: 13)).foregroundColor(.secondary)
                            .accessibilityIdentifier("trend-range")
                        Spacer()
                        if !isCurrent {
                            Button("返回本" + navigation.periodKind.title) {
                                navigation.selectTrendDay(today, today: today)
                            }.buttonStyle(.plain).font(.system(size: 12)).foregroundColor(PrototypeTheme.accent)
                                .accessibilityIdentifier("trend-return-current")
                        }
                    }.frame(minHeight: 22)
                }
                if let error = errorText {
                    Text("记录尚未成功保存：" + error)
                        .font(.system(size: 12)).foregroundColor(.red).textSelection(.enabled)
                }
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text((isCurrent ? "本" : "当") + navigation.periodKind.title + "累计")
                            .font(.system(size: 12)).foregroundColor(.secondary)
                        Text(StudyDate.duration(total)).font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundColor(PrototypeTheme.primaryInk).accessibilityIdentifier("trend-total")
                    }
                    Spacer()
                    if total == 0 {
                        Text("这一" + navigation.periodKind.title + "暂无学习记录")
                            .font(.system(size: 12)).foregroundColor(.secondary)
                    } else if isCurrent {
                        Text("今天尚未结束").font(.system(size: 12)).foregroundColor(.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("学习时长 / 小时").font(.system(size: 11)).foregroundColor(.secondary)
                    DailyStudyChart(days: days, period: period, selectedDay: selectedDay, select: { day in
                        navigation.selectTrendDay(day, today: today)
                    }, move: { offset in
                        navigation.moveTrendDay(by: offset, today: snapshot.today)
                    }).frame(height: 250)
                }
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dayLabel(selectedDay) + (selectedDay == today ? " · 截至当前" : ""))
                            .font(.system(size: 12)).foregroundColor(.secondary)
                        Text(StudyDate.duration(snapshot.totalsByDay[selectedDay, default: 0]))
                            .font(.system(size: 20, weight: .semibold))
                    }.accessibilityElement(children: .combine).accessibilityIdentifier("trend-selected-day")
                    Spacer()
                    Button("查看当日记录") { navigation.openTrendRecord(today: today) }
                        .accessibilityIdentifier("trend-open-record")
                }
            }.padding(28).frame(maxWidth: .infinity, alignment: .leading)
        }.accessibilityIdentifier("study-trend-view")
    }
}

private func dayLabel(_ day: String) -> String {
    guard let date = StudyDate.date(for: day) else { return day }
    let weekday = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"][StudyDate.calendar.component(.weekday, from: date) - 1]
    return day.replacingOccurrences(of: "-", with: "/") + " " + weekday
}

private struct DailyStudyChart: View {
    let days: [StudyDayTotal]
    let period: StudyPeriod
    let selectedDay: String
    let select: (String) -> Void
    let move: (Int) -> Void
    @State private var hoveredIndex: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selectedIndex: Int? { days.firstIndex { $0.id == selectedDay } }
    private var pastCount: Int { days.filter { $0.seconds != nil }.count }
    private var yStep: Double {
        let maximum = max(1, days.compactMap(\.seconds).max() ?? 0) / 3600
        return [0.5, 1, 2, 4, 6, 12, 24].first { maximum / $0 <= 4 } ?? 24
    }
    private var yMaximum: Double {
        let hours = (days.compactMap(\.seconds).max() ?? 0) / 3600
        return max(1, ceil(hours / yStep) * yStep)
    }
    private var yTicks: [Double] { Array(stride(from: 0.0, through: yMaximum, by: yStep)) }
    private var xTicks: [Double] {
        if period.kind == .week { return days.indices.map(Double.init) }
        return Array(Set([0, 4, 9, 14, 19, 24, days.count - 1])).sorted().map(Double.init)
    }

    var body: some View {
        Chart {
            if pastCount < days.count {
                RectangleMark(
                    xStart: .value("未来开始", Double(pastCount) - 0.5),
                    xEnd: .value("周期结束", Double(days.count) - 0.6),
                    yStart: .value("零", 0), yEnd: .value("上限", yMaximum)
                ).foregroundStyle(Color.primary.opacity(0.025)).accessibilityHidden(true)
            }
            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                if let seconds = day.seconds {
                    LineMark(x: .value("日期", Double(index)), y: .value("学习小时", seconds / 3600))
                        .foregroundStyle(PrototypeTheme.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.linear)
                        .accessibilityLabel(Text(dayLabel(day.id)))
                        .accessibilityValue(Text(StudyDate.duration(seconds)))
                    if period.kind == .week || day.id == selectedDay {
                        PointMark(x: .value("日期", Double(index)), y: .value("学习小时", seconds / 3600))
                            .foregroundStyle(PrototypeTheme.accent).symbolSize(day.id == selectedDay ? 55 : 25)
                            .accessibilityHidden(true)
                    }
                }
            }
            if let index = selectedIndex {
                RuleMark(x: .value("选中日期", Double(index)))
                    .foregroundStyle(Color.secondary.opacity(0.4)).lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .accessibilityHidden(true)
            }
            if let index = hoveredIndex, days.indices.contains(index), let seconds = days[index].seconds, index != selectedIndex {
                RuleMark(x: .value("查看日期", Double(index)))
                    .foregroundStyle(Color.secondary.opacity(0.35)).lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .accessibilityHidden(true)
                PointMark(x: .value("查看日期", Double(index)), y: .value("学习小时", seconds / 3600))
                    .foregroundStyle(PrototypeTheme.accent).symbolSize(45).accessibilityHidden(true)
            }
        }
        .chartXScale(domain: -0.4 ... Double(days.count) - 0.6,
                     range: .plotDimension(padding: period.kind == .month ? 12 : 0))
        .chartYScale(domain: 0 ... yMaximum)
        .chartXAxis {
            AxisMarks(values: xTicks) { value in
                if let position = value.as(Double.self), days.indices.contains(Int(position)) {
                    let day = days[Int(position)]
                    AxisValueLabel(centered: false, anchor: .top) {
                        VStack(spacing: 3) {
                            if period.kind == .week {
                                Text(["周日", "周一", "周二", "周三", "周四", "周五", "周六"][StudyDate.calendar.component(.weekday, from: day.date) - 1])
                                Text(String(day.id.suffix(5)).replacingOccurrences(of: "-", with: "/"))
                            } else {
                                Text("\(Int(position) + 1)日")
                            }
                        }.font(.system(size: 11)).fixedSize().foregroundColor(.secondary).opacity(day.seconds == nil ? 0.6 : 1)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: yTicks) { value in
                AxisGridLine().foregroundStyle(Color.primary.opacity(0.10))
                AxisValueLabel {
                    if let hour = value.as(Double.self) {
                        Text(hour == floor(hour) ? String(Int(hour)) : String(format: "%.1f", hour))
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                let frame = geometry[proxy.plotAreaFrame]
                ZStack(alignment: .topLeading) {
                    TrendChartInput(onHover: { location in
                        hoveredIndex = location.flatMap { index(at: $0, frame: frame, proxy: proxy) }
                    }, onSelect: { location in
                        if let index = index(at: location, frame: frame, proxy: proxy), days[index].seconds != nil {
                            select(days[index].id)
                        }
                    }, onMove: moveSelection)
                    if let index = hoveredIndex, days.indices.contains(index), let x = proxy.position(forX: Double(index)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dayLabel(days[index].id)).font(.system(size: 11)).foregroundColor(.secondary)
                            Text(days[index].seconds.map(StudyDate.duration) ?? "尚未到来")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(10).frame(width: 164, alignment: .leading)
                        .background(PrototypeTheme.surface).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(PrototypeTheme.border))
                        .position(x: min(max(frame.minX + x, 84), geometry.size.width - 84), y: frame.minY + 30)
                        .allowsHitTesting(false).accessibilityHidden(true)
                    }
                }
            }
        }
        .accessibilityRepresentation {
            VStack {
                ForEach(days) { day in
                    if let seconds = day.seconds {
                        Button(dayLabel(day.id) + "，" + StudyDate.duration(seconds)) { select(day.id) }
                            .accessibilityAddTraits(day.id == selectedDay ? .isSelected : [])
                    }
                }
            }.accessibilityElement(children: .contain)
                .accessibilityLabel("每日学习时长折线图")
        }
        .accessibilityLabel("每日学习时长折线图")
        .accessibilityIdentifier("study-trend-chart")
        .onChange(of: period.id) { _ in hoveredIndex = nil }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: period.id)
    }

    private func moveSelection(_ offset: Int) {
        hoveredIndex = nil
        move(offset)
    }

    private func index(at location: CGPoint, frame: CGRect, proxy: ChartProxy) -> Int? {
        guard location.x >= frame.minX, location.x <= frame.maxX,
              location.y >= frame.minY, location.y <= frame.maxY,
              let value = proxy.value(atX: location.x - frame.minX, as: Double.self) else { return nil }
        return min(max(0, Int(value.rounded())), days.count - 1)
    }
}

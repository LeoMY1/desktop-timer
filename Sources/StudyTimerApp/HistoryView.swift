import SwiftUI
import StudyCore

struct HistoryView: View {
    @ObservedObject var model: StudyModel
    @ObservedObject var navigation: HistoryNavigation
    var showTail: (UUID) -> Void
    var deleteRecord: (RecordDeletion) -> Void

    private var day: String { navigation.dailyDate(today: model.ledger.day) }
    private var days: [String] {
        Array(Set(model.ledger.sessions.map(\.day) + [model.ledger.day, day])).sorted(by: >)
    }

    var body: some View {
        let snapshot = StudyTrendSnapshot(ledger: model.ledger)
        let anchor = StudyDate.date(for: navigation.trendDate(today: model.ledger.day)) ?? snapshot.today
        let period = StudyPeriod(containing: anchor, kind: navigation.periodKind)
        HStack(spacing: 0) {
            sidebar(snapshot: snapshot, selection: period)
            Divider()
            if !model.ready {
                VStack(alignment: .leading, spacing: 14) {
                    Text("暂时无法读取学习记录").font(.system(size: 20, weight: .semibold))
                    Text(model.errorText ?? "请从菜单查看错误并重试。")
                        .font(.system(size: 13)).foregroundColor(.secondary).textSelection(.enabled)
                    Text("请从计时窗菜单重试加载。").font(.system(size: 12)).foregroundColor(.secondary)
                    Spacer()
                }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if navigation.section == .daily {
                DailyRecordsView(model: model, showTail: showTail, deleteRecord: deleteRecord, day: day)
            } else {
                StudyTrendView(snapshot: snapshot, navigation: navigation, errorText: model.errorText)
            }
        }
        .background(PrototypeTheme.surface)
        .frame(minWidth: 760, minHeight: 560)
    }

    private func sidebar(snapshot: StudyTrendSnapshot, selection: StudyPeriod) -> some View {
        let periods = snapshot.periods(of: navigation.periodKind, including: selection)
        let selectedID = navigation.section == .daily ? day : selection.id
        return VStack(alignment: .leading, spacing: 16) {
            Picker("记录视图", selection: Binding(
                get: { navigation.section },
                set: { navigation.selectSection($0, today: model.ledger.day) }
            )) {
                ForEach(HistorySection.allCases) { section in Text(section.title).tag(section) }
            }
            .pickerStyle(.segmented).controlSize(.small).labelsHidden()
            .accessibilityIdentifier("history-section-picker")
            .disabled(model.isEditingHistory)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 5) {
                        if !model.ready {
                            Text("无法读取记录").font(.system(size: 12)).foregroundColor(.secondary).padding(10)
                        } else if navigation.section == .daily {
                            ForEach(days, id: \.self) { date in
                                Button { navigation.selectRecord(date) } label: {
                                    HStack(spacing: 5) {
                                        Text(shortDate(date))
                                        Spacer(minLength: 0)
                                        Text(StudyDate.duration(snapshot.totalsByDay[date, default: 0]))
                                            .font(.system(size: 11)).foregroundColor(.secondary)
                                    }
                                    .font(.system(size: 13)).padding(.vertical, 12).padding(.horizontal, 10)
                                    .background(date == day ? PrototypeTheme.accent.opacity(0.13) : Color.clear)
                                    .cornerRadius(9).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain).id(date)
                                .accessibilityLabel(date + "，" + StudyDate.duration(snapshot.totalsByDay[date, default: 0]))
                                .accessibilityIdentifier("history-day-" + date)
                            }
                        } else {
                            ForEach(Array(periods.enumerated()), id: \.element.id) { index, period in
                                if index == 0 || periods[index - 1].year != period.year {
                                    Text("\(String(period.year))年").font(.system(size: 11)).foregroundColor(.secondary)
                                        .padding(.horizontal, 10).padding(.top, index == 0 ? 0 : 10)
                                }
                                periodButton(period, snapshot: snapshot, selected: period.id == selection.id)
                            }
                        }
                    }
                }
                .onAppear { proxy.scrollTo(selectedID, anchor: .center) }
                .onChange(of: selectedID) { value in proxy.scrollTo(value, anchor: .center) }
            }
            Text("学习记录保存在本机").font(.system(size: 10)).foregroundColor(.secondary).padding(.horizontal, 10)
        }
        .padding(12).padding(.top, 6).frame(width: 190)
        .background(Color.primary.opacity(0.025))
    }

    private func periodButton(_ period: StudyPeriod, snapshot: StudyTrendSnapshot, selected: Bool) -> some View {
        let total = snapshot.total(in: period)
        return Button { navigation.selectPeriod(period, today: snapshot.today) } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 4) {
                    Text(period.sidebarTitle).font(.system(size: 12))
                    Spacer(minLength: 0)
                    if period.contains(snapshot.today) {
                        Text("本" + period.kind.title).font(.system(size: 10)).foregroundColor(PrototypeTheme.accent)
                    }
                }
                Text(StudyDate.duration(total)).font(.system(size: 11)).foregroundColor(.secondary)
            }
            .padding(.horizontal, 10).padding(.vertical, 11).frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? PrototypeTheme.accent.opacity(0.13) : Color.clear)
            .cornerRadius(9).contentShape(Rectangle())
        }
        .buttonStyle(.plain).id(period.id)
        .accessibilityLabel(period.rangeTitle + "，累计" + StudyDate.duration(total))
        .accessibilityIdentifier("history-period-" + period.id)
    }

    private func shortDate(_ date: String) -> String {
        String(date.suffix(5)).replacingOccurrences(of: "-", with: "/")
    }
}

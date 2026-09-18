import SwiftUI

private struct EditingNote: Identifiable {
    let id: String
    let initial: String
}

struct HistoryView: View {
    @ObservedObject var model: PrototypeModel
    var showTail: () -> Void
    @State private var selectedDay = 0
    @State private var editing: EditingNote?
    private let dates = ["9月18日", "9月17日", "9月16日"]
    private let totals = ["2小时35分", "4小时20分", "3小时10分"]

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text("每日记录").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary).padding(.horizontal, 12).padding(.bottom, 10)
                ForEach(0..<3) { i in
                    Button { selectedDay = i } label: {
                        HStack {
                            Text(dates[i]).font(.system(size: 13))
                            Spacer()
                            Text(totals[i]).font(.system(size: 11)).foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 13)
                        .background(selectedDay == i ? PrototypeTheme.accent.opacity(0.13) : Color.clear)
                        .cornerRadius(9)
                        .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
                Spacer()
                Label("P2 演示数据", systemImage: "testtube.2")
                    .font(.system(size: 10)).foregroundColor(.secondary).padding(12)
            }
            .padding(12).padding(.top, 14)
            .frame(width: 190)
            .background(Color.primary.opacity(0.025))
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 23) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 9) {
                            Text("2026年9月\(18 - selectedDay)日").font(.system(size: 24, weight: .semibold))
                            Text("示例数据 · 仅用于界面验收").font(.system(size: 11)).foregroundColor(.secondary)
                        }
                        Spacer()
                        Label("演示", systemImage: "circle.fill").font(.system(size: 11)).foregroundColor(PrototypeTheme.accent)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(selectedDay == 0 ? "今日累计" : "当日累计").font(.system(size: 12)).foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(selectedDay == 0 ? "2" : selectedDay == 1 ? "4" : "3").font(.system(size: 46, weight: .bold, design: .rounded))
                            Text("小时").font(.system(size: 18, weight: .medium))
                            Text(selectedDay == 0 ? "35" : selectedDay == 1 ? "20" : "10").font(.system(size: 46, weight: .bold, design: .rounded))
                            Text("分钟").font(.system(size: 18, weight: .medium))
                        }.foregroundColor(PrototypeTheme.primaryInk)
                    }
                    Divider()
                    if selectedDay == 0 {
                        sessionHeader("学习段 1", range: "09:00–10:00", duration: "学习 1小时")
                        noteRow(id: "math", text: "高等数学 · 极限与连续", duration: "1小时")
                        Divider()
                        sessionHeader("学习段 2", range: "10:20–至今", duration: "学习 1小时35分钟")
                        VStack(spacing: 0) {
                            noteRow(id: "english", text: "英语阅读 · 精读两篇", duration: "1小时")
                            HStack {
                                Text(model.phase == .stopped ? "尾段待处理" : "本小时进行中").foregroundColor(.secondary)
                                Spacer()
                                Text("35分钟").foregroundColor(.secondary)
                                Button("处理", action: showTail).buttonStyle(.plain).foregroundColor(PrototypeTheme.accent)
                            }.font(.system(size: 12)).padding(13)
                        }
                    } else {
                        sessionHeader("学习段 1", range: "09:00–11:00", duration: "学习 2小时")
                        noteRow(id: "day\(selectedDay)-1", text: "高等数学 · 章节复习", duration: "2小时")
                        Divider()
                        sessionHeader("学习段 2", range: selectedDay == 1 ? "14:00–16:20" : "14:00–15:10", duration: selectedDay == 1 ? "学习 2小时20分钟" : "学习 1小时10分钟")
                        noteRow(id: "day\(selectedDay)-2", text: "英语 · 阅读与词汇", duration: selectedDay == 1 ? "2小时20分钟" : "1小时10分钟")
                    }
                }.padding(28)
            }
        }
        .background(PrototypeTheme.surface)
        .frame(minWidth: 760, minHeight: 560)
        .sheet(item: $editing) { item in
            VStack(alignment: .leading, spacing: 15) {
                Text("编辑备注 · 演示").font(.system(size: 18, weight: .semibold))
                Text("文字仅保留在本次运行，不写入学习记录。").font(.system(size: 12)).foregroundColor(.secondary)
                TextEditor(text: Binding(get: { model.noteOverrides[item.id] ?? item.initial }, set: { model.noteOverrides[item.id] = $0 }))
                    .font(.system(size: 14)).frame(height: 140)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(PrototypeTheme.border))
                HStack { Spacer(); Button("完成") { editing = nil }.keyboardShortcut(.defaultAction) }
            }.padding(24).frame(width: 400)
        }
    }

    private func sessionHeader(_ title: String, range: String, duration: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.system(size: 16, weight: .semibold))
            HStack(spacing: 14) {
                Text(range).font(.system(size: 12)).foregroundColor(.secondary)
                Text(duration).font(.system(size: 11, weight: .medium))
                    .foregroundColor(PrototypeTheme.accent)
                    .padding(.horizontal, 11).padding(.vertical, 5)
                    .background(PrototypeTheme.accent.opacity(0.10)).clipShape(Capsule())
            }
        }
    }
    private func noteRow(id: String, text: String, duration: String) -> some View {
        HStack(spacing: 12) {
            let note = model.noteOverrides[id] ?? text
            Text(note.isEmpty ? "未填写" : note).font(.system(size: 13)).lineLimit(3)
            Spacer(minLength: 8)
            Text(duration).font(.system(size: 12)).foregroundColor(.secondary)
            Button { editing = EditingNote(id: id, initial: text) } label: { Image(systemName: "pencil").frame(width: 22, height: 22) }
                .buttonStyle(.plain).foregroundColor(.secondary).help("编辑演示备注").accessibilityLabel("编辑" + text)
        }
        .padding(12)
        .background(Color.primary.opacity(0.025))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(PrototypeTheme.border, lineWidth: 0.75))
        .cornerRadius(9)
    }
}

import SwiftUI
import StudyCore

struct HistoryView: View {
    @ObservedObject var model: StudyModel
    var showTail: (UUID)->Void
    @State private var editingID: UUID?
    @State private var selectedDay: String?
    var day: String { selectedDay ?? model.ledger.day }
    var days: [String] { Array(Set(model.ledger.sessions.map(\.day) + [model.ledger.day])).sorted(by: >) }
    var sessions: [StudySession] { model.ledger.sessions.filter { $0.day == day } }
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text("每日记录").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary).padding(12)
                ScrollView {
                    VStack(spacing: 5) {
                        ForEach(days, id: \.self) { date in
                            Button { selectedDay = date } label: {
                                HStack {
                                    Text(String(date.suffix(5)).replacingOccurrences(of: "-", with: "/"))
                                    Spacer()
                                    Text(StudyDate.duration(model.ledger.total(on: date))).font(.system(size: 11)).foregroundColor(.secondary)
                                }
                                .font(.system(size: 13)).padding(12)
                                .background(date == day ? PrototypeTheme.accent.opacity(0.13) : Color.clear).cornerRadius(9)
                                .contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }
                    }
                }
                Text("学习记录保存在本机").font(.system(size: 10)).foregroundColor(.secondary).padding(12)
            }.padding(12).frame(width: 190).background(Color.primary.opacity(0.025))
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Text(day.replacingOccurrences(of: "-", with: "/")).font(.system(size: 24, weight: .semibold))
                        Spacer()
                        if day == model.ledger.day { Text(model.phaseTitle).font(.system(size: 12)).foregroundColor(PrototypeTheme.accent) }
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        Text(day == model.ledger.day ? "今日累计" : "当日累计").font(.system(size: 12)).foregroundColor(.secondary)
                        Text(StudyDate.duration(model.ledger.total(on: day)))
                            .font(.system(size: 38, weight: .bold, design: .rounded)).foregroundColor(PrototypeTheme.primaryInk)
                    }
                    if let error = model.errorText {
                        Text("记录尚未成功保存：" + error).foregroundColor(.red).font(.system(size: 12)).textSelection(.enabled)
                    }
                    Divider()
                    if sessions.isEmpty { Text(model.ready ? "这一天还没有学习记录" : "暂时无法读取学习记录，请从菜单查看错误并重试。")
                        .font(.system(size: 14)).foregroundColor(.secondary).padding(.vertical, 28) }
                    ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("学习段 \(index + 1)").font(.system(size: 16, weight: .semibold))
                                Spacer()
                                Text(StudyDate.duration(session.seconds)).font(.system(size: 13, weight: .medium)).foregroundColor(PrototypeTheme.accent)
                            }
                            HStack(spacing: 14) {
                                Text(StudyDate.clock(session.startedAt) + "–" + (session.endedAt.map { StudyDate.clock($0) } ?? "至今"))
                                Text(status(session))
                            }.font(.system(size: 12)).foregroundColor(.secondary)
                            Text("有效学习 \(StudyDate.duration(session.seconds)) · 暂停时间不计入")
                                .font(.system(size: 12)).foregroundColor(.secondary)
                            ForEach(model.ledger.entries(for:session.id)) { entry in
                                HStack(alignment:.top,spacing:8) {
                                    VStack(alignment:.leading,spacing:5) {
                                        Text(model.note(entry.id).isEmpty ? "未填写学习内容" : model.note(entry.id))
                                            .font(.system(size:13)).foregroundColor(model.note(entry.id).isEmpty ? .secondary : .primary)
                                            .fixedSize(horizontal:false,vertical:true)
                                        if entry.pendingTail { Text("尾段待处理").font(.system(size:10)).foregroundColor(.orange) }
                                    }
                                    Spacer()
                                    Text(StudyDate.duration(entry.seconds)).font(.system(size:12)).foregroundColor(.secondary)
                                    Button { model.isEditingHistory=true;editingID=entry.id } label: {
                                        Image(systemName:"pencil").frame(width:20,height:20).contentShape(Rectangle())
                                    }.buttonStyle(.plain).accessibilityLabel("编辑学习内容")
                                    if entry.pendingTail {
                                        Button("处理"){showTail(entry.id)}.font(.system(size:11)).buttonStyle(.plain).foregroundColor(PrototypeTheme.accent)
                                    }
                                }.padding(10).background(PrototypeTheme.surface).cornerRadius(8)
                            }
                            let recorded=model.ledger.entries(for:session.id).last?.endOffset ?? 0
                            if session.endedAt==nil && session.seconds-recorded>0.001 {
                                HStack { Text("当前学习内容待整小时或停止后记录");Spacer();Text(StudyDate.duration(session.seconds-recorded)) }
                                    .font(.system(size:11)).foregroundColor(.secondary)
                            }
                        }.padding(16).background(Color.primary.opacity(0.025)).cornerRadius(10)
                    }

                }.padding(28).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.background(PrototypeTheme.surface).frame(minWidth:760,minHeight:560)
        .sheet(isPresented:Binding(get:{editingID != nil},set:{if !$0 {finishEditing()}})) {
            if let id=editingID {
                VStack(alignment:.leading,spacing:12) {
                    Text("编辑学习内容").font(.system(size:18,weight:.semibold))
                    Text("备注自动保存，可修改或清空；学习时长不变。").font(.system(size:12)).foregroundColor(.secondary)
                    ClickToEditField(text:Binding(get:{model.note(id)},set:{model.setNote(id,$0)}),onEscape:finishEditing)
                        .frame(height:150).overlay(RoundedRectangle(cornerRadius:8).stroke(PrototypeTheme.border))
                    if let error=model.errorText {Text("保存失败："+error).font(.system(size:11)).foregroundColor(.red)}
                    HStack { Spacer();Button("完成",action:finishEditing).keyboardShortcut(.defaultAction) }
                }.padding(24).frame(width:420).interactiveDismissDisabled()
            }
        }
    }
    func finishEditing() { if model.flushDrafts() {editingID=nil;model.isEditingHistory=false} }
    func status(_ session: StudySession) -> String {
        if session.endedAt == nil { return model.phase == .paused ? "已暂停" : "学习中" }
        switch session.endReason {
        case .midnight: return "跨日分段"
        case .quit: return "退出时结束"
        case .interrupted: return "已恢复至最后保存点"
        default: return "已结束"
        }
    }
}

import SwiftUI
import StudyCore

struct NoteCard: View {
    @ObservedObject var model: StudyModel
    var close: ()->Void
    var save: ()->Void
    var merge: ()->Void
    var next: (Int)->Void
    var body: some View {
        VStack(alignment:.leading,spacing:9) {
            HStack {
                Text(model.cardTitle).font(.system(size:14,weight:.semibold))
                Spacer()
                Button(action:close){Image(systemName:"xmark").frame(width:20,height:20).contentShape(Rectangle())}
                    .buttonStyle(.plain).foregroundColor(.secondary).accessibilityLabel("收起备注卡片")
            }
            if let entry=model.currentEntry {
                let day=model.ledger.sessions.first{$0.id==entry.sessionID}?.day ?? ""
                Text("\(day) · 本条 \(StudyDate.duration(entry.seconds))")
                    .font(.system(size:11)).foregroundColor(.secondary)
                if model.cardEntryIDs.count>1 {
                    HStack {
                        Button("上一条"){next(-1)}.disabled(model.cardIndex==0)
                        Spacer();Text("\(model.cardIndex+1) / \(model.cardEntryIDs.count)");Spacer()
                        Button("下一条"){next(1)}.disabled(model.cardIndex+1==model.cardEntryIDs.count)
                    }.font(.system(size:11)).buttonStyle(.plain)
                }
                ZStack(alignment:.topLeading) {
                    if model.note(entry.id).isEmpty {
                        Text("记录刚才的学习内容…").font(.system(size:12)).foregroundColor(.secondary.opacity(0.7))
                            .padding(.top,9).padding(.leading,11).allowsHitTesting(false)
                    }
                    ClickToEditField(text:Binding(get:{model.note(entry.id)},set:{model.setNote(entry.id,$0)}),onEscape:close)
                        .id(entry.id)
                }.frame(height:80).background(Color.primary.opacity(0.025)).cornerRadius(9)
                    .overlay(RoundedRectangle(cornerRadius:9).stroke(PrototypeTheme.border))
                if let error=model.errorText {
                    Text("保存失败，请重试："+error).font(.system(size:10)).foregroundColor(.red).lineLimit(2)
                } else {
                    Text(model.hasUnsavedNotes ? "正在保存…" : "备注已保存在本机").font(.system(size:10)).foregroundColor(.secondary)
                }
                if entry.pendingTail {
                    HStack(spacing:8) {
                        Button("合并上一条",action:merge).buttonStyle(DemoButtonStyle()).disabled(!model.ledger.canMerge(entry.id))
                        Button("单独记录",action:save).buttonStyle(DemoButtonStyle(prominent:true))
                    }
                    Button("稍后处理",action:close).buttonStyle(.plain).font(.system(size:11)).foregroundColor(.secondary)
                } else {
                    HStack(spacing:8) {
                        Button("稍后填写",action:close).buttonStyle(DemoButtonStyle())
                        Button("保存",action:save).buttonStyle(DemoButtonStyle(prominent:true))
                    }
                }
                Text(ReminderCoordinator.pending(in:model.ledger).isEmpty ? (model.phase == .running ? "计时继续中" : "可随时在历史记录补填") : "有新的整小时记录，完成当前填写后显示")
                    .font(.system(size:10)).foregroundColor(PrototypeTheme.accent).lineLimit(1)
            }
        }.padding(15).padding(.bottom,9).frame(width:288,height:300,alignment:.top)
            .background(PopupOutline().fill(PrototypeTheme.surface))
            .overlay(PopupOutline().stroke(PrototypeTheme.border,lineWidth:1))
    }
}

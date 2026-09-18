import SwiftUI

struct TimerView: View {
    @ObservedObject var model: PrototypeModel
    var primary: () -> Void
    var stop: () -> Void
    var history: () -> Void
    var showMenu: () -> Void
    var beginDrag: () -> Void
    var endDrag: () -> Void

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 7) {
                Text("今日学习").font(.system(size: 13, weight: .semibold))
                    .overlay(DragRegion(onStart: beginDrag, onEnd: endDrag))
                Spacer(minLength: 2)
                Circle().fill(model.phase == .running ? PrototypeTheme.accent : model.phase == .paused ? .orange.opacity(0.7) : .gray.opacity(0.65)).frame(width: 6, height: 6)
                Text(model.phase.title).font(.system(size: 11)).foregroundColor(.secondary)
                    .overlay(DragRegion(onStart: beginDrag, onEnd: endDrag))
                Button(action: history) { Image(systemName: "text.badge.plus").frame(width: 20, height: 20) }
                    .buttonStyle(.plain).foregroundColor(.secondary).help("查看学习记录（演示数据）").accessibilityLabel("查看学习记录")
                Button(action: showMenu) { Image(systemName: "ellipsis").frame(width: 16, height: 20) }
                    .buttonStyle(.plain).foregroundColor(.secondary).help("原型演示与设置").accessibilityLabel("原型演示菜单")
            }
            ZStack {
                Text(model.displayTime)
                    .font(.system(size: 51, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundColor(PrototypeTheme.primaryInk)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .overlay(DragRegion(onStart: beginDrag, onEnd: endDrag))
                if model.celebration {
                    HStack {
                        Image(systemName: "sparkles")
                        Spacer()
                        Image(systemName: "sparkle")
                    }
                    .font(.system(size: 20))
                    .foregroundColor(PrototypeTheme.accent.opacity(0.8))
                    .allowsHitTesting(false)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            HStack(spacing: 9) {
                Button(action: primary) {
                    Label(model.phase == .running ? "暂停" : model.phase == .paused ? "继续学习" : "开始学习",
                          systemImage: model.phase == .running ? "pause.fill" : "play.fill")
                }.buttonStyle(DemoButtonStyle(prominent: true))
                if model.phase == .running || model.phase == .paused {
                    Button(action: stop) { Label("停止学习", systemImage: "stop.fill") }
                        .buttonStyle(DemoButtonStyle())
                }
            }
            Text(model.delayedPromptPending ? "8秒后演示弹窗 · 请切回其他应用" : model.feedback.isEmpty ? "P2 交互原型 · 示例时间，不计时" : model.feedback)
                .font(.system(size: 9.5))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 15).padding(.vertical, 12)
        .frame(width: 288, height: 176)
        .background(PrototypeTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(PrototypeTheme.border, lineWidth: 1))
    }
}

struct NoteCardView: View {
    @ObservedObject var model: PrototypeModel
    var close: () -> Void
    var save: () -> Void
    var merge: () -> Void

    private var binding: Binding<String> {
        Binding(get: { model.card == .hourly ? model.hourlyDraft : model.tailDraft }, set: {
            if model.card == .hourly { model.hourlyDraft = $0 } else { model.tailDraft = $0 }
        })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(model.card == .hourly ? "又完成一小时" : "最后 35 分钟").font(.system(size: 15, weight: .semibold))
                Spacer()
                Button(action: close) { Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)).frame(width: 19, height: 19) }
                    .buttonStyle(.plain).foregroundColor(.secondary).help("收起卡片").accessibilityLabel("收起卡片")
            }
            Text(model.card == .hourly ? "今天已累计学习 2 小时" : "选择这段学习的记录方式")
                .font(.system(size: 11)).foregroundColor(.secondary)
            ZStack(alignment: .topLeading) {
                if binding.wrappedValue.isEmpty {
                    Text("记录刚才的学习内容…")
                        .font(.system(size: 12)).foregroundColor(.secondary.opacity(0.7))
                        .padding(.top, 9).padding(.leading, 11)
                        .allowsHitTesting(false)
                }
                ClickToEditField(text: binding, onEscape: close)
            }
            .frame(height: 73)
            .background(Color.primary.opacity(0.025))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(PrototypeTheme.border, lineWidth: 1))
            if model.card == .hourly {
                HStack(spacing: 9) {
                    Button("稍后填写", action: close).buttonStyle(DemoButtonStyle())
                    Button("保存", action: save).buttonStyle(DemoButtonStyle(prominent: true))
                }
            } else {
                HStack(spacing: 8) {
                    Button("合并上一条", action: merge).buttonStyle(DemoButtonStyle())
                    Button("单独记录", action: save).buttonStyle(DemoButtonStyle(prominent: true))
                }
            }
            Text("交互演示 · 文字仅保留在本次运行")
                .font(.system(size: 9.5)).foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
        }
        .padding(15).padding(.bottom, 9)
        .frame(width: 288, height: 244, alignment: .top)
        .background(PopupOutline().fill(PrototypeTheme.surface))
        .overlay(PopupOutline().stroke(PrototypeTheme.border, lineWidth: 1))
    }
}


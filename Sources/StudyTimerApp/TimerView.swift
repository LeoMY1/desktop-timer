import SwiftUI

private struct TimerControlBounds: PreferenceKey {
    static var defaultValue: [Anchor<CGRect>] = []
    static func reduce(value: inout [Anchor<CGRect>], nextValue: () -> [Anchor<CGRect>]) {
        value.append(contentsOf: nextValue())
    }
}

private extension View {
    func timerControl() -> some View {
        anchorPreference(key: TimerControlBounds.self, value: .bounds) { [$0] }
    }
}

struct TimerView: View {
    @ObservedObject var model: StudyModel
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
                Spacer(minLength: 2)
                Circle().fill(model.phase == .running ? PrototypeTheme.accent : model.phase == .paused ? .orange.opacity(0.7) : .gray.opacity(0.65)).frame(width: 6, height: 6)
                Text(model.phaseTitle).font(.system(size: 11)).foregroundColor(.secondary)
                Button(action: history) {
                    Image(systemName: "text.badge.plus")
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                    .buttonStyle(.plain).foregroundColor(.secondary).help("查看学习记录").accessibilityLabel("查看学习记录")
                    .timerControl()
                Button(action: showMenu) {
                    Image(systemName: "ellipsis")
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                    .buttonStyle(.plain).foregroundColor(.secondary).help("计时操作与外观").accessibilityLabel("计时菜单")
                    .timerControl()
            }
            ZStack {
                Text(model.displayTime)
                    .font(.system(size: 51, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundColor(PrototypeTheme.primaryInk)
                    .frame(maxWidth: .infinity, minHeight: 56)

            }
            HStack(spacing: 9) {
                Button(action: primary) {
                    Label(model.phase == .running ? "暂停" : model.phase == .paused ? "继续学习" : "开始学习",
                          systemImage: model.phase == .running ? "pause.fill" : "play.fill")
                }.buttonStyle(DemoButtonStyle(prominent: true)).disabled(!model.ready).timerControl()
                if model.phase == .running || model.phase == .paused {
                    Button(action: stop) { Label("停止学习", systemImage: "stop.fill") }
                        .buttonStyle(DemoButtonStyle())
                        .timerControl()
                }
            }
            Text(model.footer)
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
        .overlayPreferenceValue(TimerControlBounds.self) { anchors in
            GeometryReader { geometry in
                DragRegion(onStart: beginDrag, onEnd: endDrag,
                           excludedRects: anchors.map { geometry[$0] })
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }
}


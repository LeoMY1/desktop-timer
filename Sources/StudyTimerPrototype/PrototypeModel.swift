import SwiftUI

enum DemoPhase: String, CaseIterable {
    case idle, running, paused, stopped
    var title: String {
        switch self {
        case .idle: return "未开始"
        case .running: return "学习中"
        case .paused: return "已暂停"
        case .stopped: return "已停止"
        }
    }
}

enum DemoCard: String { case hourly, tail }

/// P2 only: explicit in-memory fixtures. No elapsed-time clock or study database.
final class PrototypeModel: ObservableObject {
    @Published var phase: DemoPhase = .idle
    @Published var displayTime = "00:00"
    @Published var card: DemoCard = .hourly
    @Published var hourlyDraft = ""
    @Published var tailDraft = ""
    @Published var noteOverrides: [String: String] = [:]
    @Published var celebration = false
    @Published var feedback = ""
    @Published var delayedPromptPending = false

    func primaryAction() {
        switch phase {
        case .idle, .stopped:
            if displayTime == "00:00" { displayTime = "02:35" }
            phase = .running
        case .running: phase = .paused
        case .paused: phase = .running
        }
    }

    func setFixture(_ state: DemoPhase) {
        phase = state
        celebration = false
        switch state {
        case .idle: displayTime = "00:00"
        case .running, .stopped: displayTime = "02:35"
        case .paused: displayTime = "01:25"
        }
    }
}

enum PrototypeTheme {
    static let accent = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(red: 0.52, green: 0.77, blue: 0.71, alpha: 1)
            : NSColor(red: 0.24, green: 0.48, blue: 0.44, alpha: 1)
    })
    static let surface = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(red: 0.14, green: 0.18, blue: 0.19, alpha: 1)
            : NSColor(red: 0.985, green: 0.985, blue: 0.98, alpha: 1)
    })
    static let primaryInk = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(red: 0.94, green: 0.96, blue: 0.96, alpha: 1)
            : NSColor(red: 0.08, green: 0.17, blue: 0.18, alpha: 1)
    })
    static let border = Color.primary.opacity(0.12)
}

struct DemoButtonStyle: ButtonStyle {
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .frame(maxWidth: .infinity, minHeight: 32)
            .foregroundColor(prominent ? Color.white : .primary)
            .background(prominent ? Color(red: 0.25, green: 0.50, blue: 0.46) : Color.primary.opacity(0.065))
            .cornerRadius(9)
            .opacity(configuration.isPressed ? 0.73 : 1)
    }
}

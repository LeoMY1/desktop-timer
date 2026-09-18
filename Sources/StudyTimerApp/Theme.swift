import SwiftUI

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

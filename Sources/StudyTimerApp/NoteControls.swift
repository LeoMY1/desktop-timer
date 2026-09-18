import AppKit
import SwiftUI

final class ClickToEditTextView: NSTextView {
    var onEscape: (() -> Void)?
    override var needsPanelToBecomeKey: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        super.mouseDown(with: event)
    }
    override func cancelOperation(_ sender: Any?) { onEscape?() }
}

/// Native NSTextView keeps selection/IME intact and only takes focus after a click.
struct ClickToEditField: NSViewRepresentable {
    @Binding var text: String
    var onEscape: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        let input = ClickToEditTextView(frame: .zero)
        input.isRichText = false
        input.isAutomaticQuoteSubstitutionEnabled = false
        input.isAutomaticDashSubstitutionEnabled = false
        input.isAutomaticTextReplacementEnabled = false
        input.font = .systemFont(ofSize: 13)
        input.textColor = .labelColor
        input.drawsBackground = false
        input.textContainerInset = NSSize(width: 8, height: 7)
        input.isVerticallyResizable = true
        input.isHorizontallyResizable = false
        input.autoresizingMask = [.width]
        input.textContainer?.widthTracksTextView = true
        input.textContainer?.containerSize = NSSize(width: 260, height: CGFloat.greatestFiniteMagnitude)
        input.delegate = context.coordinator
        input.onEscape = onEscape
        input.string = text
        input.setAccessibilityLabel("学习内容备注")
        scroll.documentView = input
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let input = scroll.documentView as? ClickToEditTextView else { return }
        context.coordinator.parent = self
        input.onEscape = onEscape
        // Never replace text storage during marked-text composition.
        if input.string != text && !input.hasMarkedText() { input.string = text }
        input.textColor = .labelColor
    }
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ClickToEditField
        init(_ parent: ClickToEditField) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let input = notification.object as? NSTextView else { return }
            parent.text = input.string
        }
    }
}

struct PopupOutline: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path(roundedRect: CGRect(x: 0, y: 0, width: rect.width, height: rect.height - 9), cornerRadius: 15)
        path.move(to: CGPoint(x: rect.midX - 9, y: rect.maxY - 9))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX + 9, y: rect.maxY - 9))
        path.closeSubpath()
        return path
    }
}

import AppKit
import SwiftUI

/// Native input lets the chart accept arrow keys without requiring macOS Keyboard Navigation.
struct TrendChartInput: NSViewRepresentable {
    var onHover: (CGPoint?) -> Void
    var onSelect: (CGPoint) -> Void
    var onMove: (Int) -> Void

    func makeNSView(context: Context) -> TrendChartInputView { TrendChartInputView() }
    func updateNSView(_ view: TrendChartInputView, context: Context) {
        view.onHover = onHover; view.onSelect = onSelect; view.onMove = onMove
    }
}

final class TrendChartInputView: NSView {
    var onHover: (CGPoint?) -> Void = { _ in }
    var onSelect: (CGPoint) -> Void = { _ in }
    var onMove: (Int) -> Void = { _ in }
    private var hoverArea: NSTrackingArea?
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
        setAccessibilityElement(false)
    }
    override func updateTrackingAreas() {
        if let area = hoverArea { removeTrackingArea(area) }
        super.updateTrackingAreas()
        let area = NSTrackingArea(rect: .zero,
                                  options: [.activeAlways, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited],
                                  owner: self, userInfo: nil)
        addTrackingArea(area); hoverArea = area
    }
    override func mouseEntered(with event: NSEvent) { mouseMoved(with: event) }
    override func mouseMoved(with event: NSEvent) { onHover(convert(event.locationInWindow, from: nil)) }
    override func mouseExited(with event: NSEvent) { onHover(nil) }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        onSelect(convert(event.locationInWindow, from: nil))
    }
    override func keyDown(with event: NSEvent) {
        guard event.modifierFlags.intersection([.command, .option, .control]).isEmpty else {
            super.keyDown(with: event); return
        }
        switch event.keyCode {
        case 123: onMove(-1)
        case 124: onMove(1)
        default: super.keyDown(with: event)
        }
    }
}

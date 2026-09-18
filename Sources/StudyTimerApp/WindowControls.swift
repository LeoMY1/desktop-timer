import AppKit
import SwiftUI

final class PrototypePanel: NSPanel {
    let permitsTextInput: Bool
    init(frame: NSRect, permitsTextInput: Bool) {
        self.permitsTextInput = permitsTextInput
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        animationBehavior = .none
        isMovableByWindowBackground = false
    }
    override var canBecomeKey: Bool { permitsTextInput }
    override var canBecomeMain: Bool { false }
}

final class PassiveHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var needsPanelToBecomeKey: Bool { false }
}

struct DragRegion: NSViewRepresentable {
    var onStart: () -> Void
    var onEnd: () -> Void
    var excludedRects: [CGRect] = []
    func makeNSView(context: Context) -> DragView {
        let view = DragView()
        view.onStart = onStart
        view.onEnd = onEnd
        view.excludedRects = excludedRects
        return view
    }
    func updateNSView(_ view: DragView, context: Context) {
        view.onStart = onStart
        view.onEnd = onEnd
        view.excludedRects = excludedRects
    }
}

final class DragView: NSView {
    var onStart: () -> Void = {}
    var onEnd: () -> Void = {}
    var excludedRects: [CGRect] = [] {
        didSet { window?.invalidateCursorRects(for: self) }
    }
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        guard bounds.contains(local), !excludedRects.contains(where: { $0.contains(local) }) else { return nil }
        return self
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var needsPanelToBecomeKey: Bool { false }
    override func mouseDown(with event: NSEvent) {
        onStart()
        window?.performDrag(with: event)
        onEnd()
    }
    override func resetCursorRects() {
        // Subtract control rectangles so buttons retain their normal pointer.
        var regions = [bounds]
        for excluded in excludedRects {
            regions = regions.flatMap { rect -> [CGRect] in
                let cut = rect.intersection(excluded)
                guard !cut.isNull, !cut.isEmpty else { return [rect] }
                return [
                    CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: cut.minY - rect.minY),
                    CGRect(x: rect.minX, y: cut.maxY, width: rect.width, height: rect.maxY - cut.maxY),
                    CGRect(x: rect.minX, y: cut.minY, width: cut.minX - rect.minX, height: cut.height),
                    CGRect(x: cut.maxX, y: cut.minY, width: rect.maxX - cut.maxX, height: cut.height)
                ].filter { !$0.isEmpty }
            }
        }
        for rect in regions { addCursorRect(rect, cursor: .openHand) }
    }
}


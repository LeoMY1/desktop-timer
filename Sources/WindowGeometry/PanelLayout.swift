import Foundation
import CoreGraphics

/// Pure window-placement policy. Contains no timer, learning data or persistence.
public enum PanelLayout {
    public static func clamped(_ frame: CGRect, to visible: CGRect, margin: CGFloat = 8) -> CGRect {
        let bounds = visible.insetBy(dx: margin, dy: margin)
        let width = min(frame.width, bounds.width)
        let height = min(frame.height, bounds.height)
        return CGRect(
            x: min(max(frame.minX, bounds.minX), bounds.maxX - width),
            y: min(max(frame.minY, bounds.minY), bounds.maxY - height),
            width: width, height: height
        )
    }

    public struct Placement {
        public let timer: CGRect
        public let popup: CGRect
        public let shifted: Bool
    }

    public static func above(timer: CGRect, popupSize: CGSize, visible: CGRect, gap: CGFloat = 3) -> Placement {
        let bounds = visible.insetBy(dx: 8, dy: 8)
        var adjusted = clamped(timer, to: visible)
        let popupHeight = min(popupSize.height, max(1, bounds.height - adjusted.height - gap))
        let popupWidth = min(popupSize.width, bounds.width)
        if adjusted.maxY + gap + popupHeight > bounds.maxY {
            adjusted.origin.y = max(bounds.minY, bounds.maxY - popupHeight - gap - adjusted.height)
        }
        let popup = CGRect(
            x: min(max(adjusted.midX - popupWidth / 2, bounds.minX), bounds.maxX - popupWidth),
            y: adjusted.maxY + gap,
            width: popupWidth, height: popupHeight
        )
        return Placement(timer: adjusted, popup: popup, shifted: abs(adjusted.minY - timer.minY) > 0.5 || abs(adjusted.minX - timer.minX) > 0.5)
    }
}

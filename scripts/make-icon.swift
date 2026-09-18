import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let side = CGFloat(pixels)
        NSColor(red: 0.24, green: 0.48, blue: 0.44, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: side * 0.08, y: side * 0.08, width: side * 0.84, height: side * 0.84), xRadius: side * 0.2, yRadius: side * 0.2).fill()
        NSColor.white.setStroke()
        let circle = NSBezierPath(ovalIn: NSRect(x: side * 0.25, y: side * 0.25, width: side * 0.5, height: side * 0.5))
        circle.lineWidth = side * 0.045
        circle.stroke()
        let hands = NSBezierPath()
        hands.move(to: NSPoint(x: side * 0.5, y: side * 0.68))
        hands.line(to: NSPoint(x: side * 0.5, y: side * 0.5))
        hands.line(to: NSPoint(x: side * 0.62, y: side * 0.43))
        hands.lineWidth = side * 0.045
        hands.lineCapStyle = .round
        hands.stroke()
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}


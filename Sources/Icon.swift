import AppKit

enum MenuIcon {
    /// Template glyph for the menu bar. Black strokes; AppKit tints it.
    static func image(side: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            drawPower(in: rect, color: .black)
            return true
        }
        image.isTemplate = true
        return image
    }

    static func drawPower(in rect: NSRect, color: NSColor) {
        let side = min(rect.width, rect.height)
        let line = max(1.15, side * 0.078)
        let center = NSPoint(x: rect.midX, y: rect.midY - side * 0.035)
        let radius = side * 0.292

        let ring = NSBezierPath()
        ring.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: 128,
            endAngle: 52,
            clockwise: false
        )
        ring.lineWidth = line
        ring.lineCapStyle = .round
        color.setStroke()
        ring.stroke()

        let stem = NSBezierPath()
        stem.move(to: NSPoint(x: center.x, y: center.y + radius * 0.08))
        stem.line(to: NSPoint(x: center.x, y: center.y + radius + line * 0.05))
        stem.lineWidth = line
        stem.lineCapStyle = .round
        stem.stroke()
    }

    static func appIconPixels(_ pixels: Int) -> Data {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return Data() }
        rep.size = NSSize(width: pixels, height: pixels)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let rect = NSRect(x: 0, y: 0, width: pixels, height: pixels)
        let shape = NSBezierPath(roundedRect: rect, xRadius: CGFloat(pixels) * 0.223, yRadius: CGFloat(pixels) * 0.223)
        shape.addClip()
        let gradient = NSGradient(colors: [
            NSColor(srgbRed: 0.23, green: 0.25, blue: 0.28, alpha: 1),
            NSColor(srgbRed: 0.08, green: 0.09, blue: 0.11, alpha: 1),
        ])
        gradient?.draw(in: rect, angle: -90)
        let glyph = rect.insetBy(dx: CGFloat(pixels) * 0.28, dy: CGFloat(pixels) * 0.28)
        drawPower(in: glyph, color: .white)
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:]) ?? Data()
    }
}

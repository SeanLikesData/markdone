import AppKit

/// The menu bar icon for Markdone: the Markdown checkbox syntax itself — a pair
/// of square brackets with a checkmark bursting slightly out of them, "[✓]".
/// It is the literal thing the app is about (clickable Markdown checkboxes).
/// Drawn as a monochrome template image so macOS tints it for light and dark
/// menu bars.
enum StatusIcon {
    static var markdone: NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)

        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor.black.setStroke()

        // Left bracket "[".
        let left = NSBezierPath()
        left.move(to: NSPoint(x: 6.2, y: 14.0))
        left.line(to: NSPoint(x: 3.6, y: 14.0))
        left.line(to: NSPoint(x: 3.6, y: 4.0))
        left.line(to: NSPoint(x: 6.2, y: 4.0))
        left.lineWidth = 1.6
        left.lineJoinStyle = .miter
        left.lineCapStyle = .round
        left.stroke()

        // Right bracket "]".
        let right = NSBezierPath()
        right.move(to: NSPoint(x: 11.8, y: 14.0))
        right.line(to: NSPoint(x: 14.4, y: 14.0))
        right.line(to: NSPoint(x: 14.4, y: 4.0))
        right.line(to: NSPoint(x: 11.8, y: 4.0))
        right.lineWidth = 1.6
        right.lineJoinStyle = .miter
        right.lineCapStyle = .round
        right.stroke()

        // Bold checkmark, sitting a touch high so it "bursts" out of the box.
        let check = NSBezierPath()
        check.move(to: NSPoint(x: 5.8, y: 8.6))
        check.line(to: NSPoint(x: 8.3, y: 5.8))
        check.line(to: NSPoint(x: 12.6, y: 13.2))
        check.lineWidth = 2.1
        check.lineCapStyle = .round
        check.lineJoinStyle = .round
        check.stroke()

        image.isTemplate = true
        image.accessibilityDescription = "Markdone"
        return image
    }
}

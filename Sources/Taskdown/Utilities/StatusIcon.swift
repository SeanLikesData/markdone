import AppKit

/// A custom template menu bar icon for Taskdown: a small checklist — a rounded
/// card with a checkmark on the top line and two plain lines below. Drawn as a
/// monochrome template image so macOS tints it for light and dark menu bars.
enum StatusIcon {
    static var taskdown: NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)

        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor.black.setStroke()
        NSColor.black.setFill()

        let body = NSBezierPath(roundedRect: NSRect(x: 2.5, y: 2.5, width: 13.0, height: 13.0), xRadius: 3.0, yRadius: 3.0)
        body.lineWidth = 1.6
        body.stroke()

        // Checkmark on the first line.
        let check = NSBezierPath()
        check.move(to: NSPoint(x: 5.0, y: 11.3))
        check.line(to: NSPoint(x: 6.6, y: 9.8))
        check.line(to: NSPoint(x: 9.2, y: 12.6))
        check.lineWidth = 1.5
        check.lineCapStyle = .round
        check.lineJoinStyle = .round
        check.stroke()

        drawLine(from: NSPoint(x: 10.4, y: 11.0), to: NSPoint(x: 13.0, y: 11.0))
        drawLine(from: NSPoint(x: 5.0, y: 7.4), to: NSPoint(x: 13.0, y: 7.4))
        drawLine(from: NSPoint(x: 5.0, y: 5.0), to: NSPoint(x: 11.2, y: 5.0))

        image.isTemplate = true
        image.accessibilityDescription = "Taskdown"
        return image
    }

    private static func drawLine(from start: NSPoint, to end: NSPoint) {
        let path = NSBezierPath()
        path.move(to: start)
        path.line(to: end)
        path.lineCapStyle = .round
        path.lineWidth = 1.35
        path.stroke()
    }
}

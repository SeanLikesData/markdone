import SwiftUI
import AppKit

/// The `.taskdownListMarker` attribute values the styler emits. Checkboxes are
/// drawn as SF Symbols; bullets are drawn as text.
enum ListMarker {
    static let checked = "☑"
    static let unchecked = "☐"
}

/// Draws the replacement glyphs (checkbox boxes and bullets) that the
/// `MarkdownStyler` marks with the `.taskdownListMarker` attribute, on top of
/// the (invisible) source characters. Checkboxes render as crisp, slightly
/// oversized SF Symbols so they read as real, clickable controls.
final class MarkdownLayoutManager: NSLayoutManager {
    private static var imageCache: [String: NSImage] = [:]
    private static let uncheckedColor = NSColor(white: 0.62, alpha: 1.0)
    private static let checkedColor = NSColor(srgbRed: 0.45, green: 0.80, blue: 0.52, alpha: 1.0)

    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
        guard let textStorage else { return }

        let characterRange = characterRange(
            forGlyphRange: glyphsToShow,
            actualGlyphRange: nil
        )
        textStorage.enumerateAttribute(
            .taskdownListMarker,
            in: characterRange,
            options: []
        ) { value, range, _ in
            guard let symbol = value as? String else { return }
            let glyphRange = self.glyphRange(
                forCharacterRange: range,
                actualCharacterRange: nil
            )
            guard glyphRange.length > 0 else { return }

            let location = self.location(forGlyphAt: glyphRange.location)
            let lineFragment = self.lineFragmentRect(
                forGlyphAt: glyphRange.location,
                effectiveRange: nil
            )
            let font = textStorage.attribute(
                .font,
                at: range.location,
                effectiveRange: nil
            ) as? NSFont ?? .systemFont(ofSize: NSFont.systemFontSize)

            if symbol == ListMarker.checked || symbol == ListMarker.unchecked {
                let checked = symbol == ListMarker.checked
                // Oversize the box relative to the text so it is easy to see and
                // click; the styler reserves a fixed slot wide enough for it.
                let boxSize = (font.pointSize * 1.25).rounded()
                guard let image = Self.checkboxImage(checked: checked, pointSize: boxSize) else { return }
                let drawRect = NSRect(
                    x: origin.x + lineFragment.minX + location.x + 1,
                    y: origin.y + lineFragment.minY + ((lineFragment.height - image.size.height) / 2),
                    width: image.size.width,
                    height: image.size.height
                )
                image.draw(
                    in: drawRect,
                    from: .zero,
                    operation: .sourceOver,
                    fraction: 1,
                    respectFlipped: true,
                    hints: nil
                )
            } else {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: NSColor.textColor
                ]
                let symbolSize = (symbol as NSString).size(withAttributes: attributes)
                let point = NSPoint(
                    x: origin.x + lineFragment.minX + location.x,
                    y: origin.y + lineFragment.minY
                        + ((lineFragment.height - symbolSize.height) / 2)
                )
                (symbol as NSString).draw(at: point, withAttributes: attributes)
            }
        }
    }

    /// A cached, tinted SF Symbol checkbox image. Fixed colors (the app is always
    /// dark) keep it crisp and predictable.
    static func checkboxImage(checked: Bool, pointSize: CGFloat) -> NSImage? {
        let key = "\(checked)-\(Int(pointSize))"
        if let cached = imageCache[key] { return cached }
        let name = checked ? "checkmark.square.fill" : "square"
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return nil }
        let color = checked ? checkedColor : uncheckedColor
        let tinted = NSImage(size: base.size, flipped: false) { rect in
            base.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        tinted.isTemplate = false
        imageCache[key] = tinted
        return tinted
    }
}

/// An `NSTextView` that toggles a Markdown checkbox when its rendered box is
/// clicked, without moving the insertion point or entering edit mode.
final class MarkdownTextView: NSTextView {
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 1, toggleCheckboxIfClicked(event) {
            return
        }
        super.mouseDown(with: event)
    }

    /// Returns true if the click landed on a checkbox and was handled.
    private func toggleCheckboxIfClicked(_ event: NSEvent) -> Bool {
        guard let layoutManager, let textContainer, let textStorage,
              layoutManager.numberOfGlyphs > 0
        else { return false }

        let text = string as NSString
        guard text.length > 0 else { return false }

        let viewPoint = convert(event.locationInWindow, from: nil)
        let containerPoint = NSPoint(
            x: viewPoint.x - textContainerOrigin.x,
            y: viewPoint.y - textContainerOrigin.y
        )

        var fraction: CGFloat = 0
        let glyphIndex = layoutManager.glyphIndex(
            for: containerPoint,
            in: textContainer,
            fractionOfDistanceThroughGlyph: &fraction
        )
        guard glyphIndex < layoutManager.numberOfGlyphs else { return false }
        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        guard charIndex < text.length else { return false }

        let lineRange = text.lineRange(for: NSRange(location: charIndex, length: 0))
        guard let marker = MarkdownTasks.marker(in: text, lineRange: lineRange) else {
            return false
        }

        // Only toggle when the click is actually within the rendered marker box,
        // not just anywhere on the task line.
        let markerGlyphRange = layoutManager.glyphRange(
            forCharacterRange: marker.hitRange,
            actualCharacterRange: nil
        )
        let markerRect = layoutManager.boundingRect(forGlyphRange: markerGlyphRange, in: textContainer)
        guard markerRect.contains(containerPoint) else { return false }

        let replacement = marker.toggledReplacement
        // If the change is vetoed, fall through to normal click handling so the
        // user can still place the cursor.
        guard shouldChangeText(in: marker.bracketRange, replacementString: replacement) else {
            return false
        }
        textStorage.beginEditing()
        textStorage.replaceCharacters(in: marker.bracketRange, with: replacement)
        textStorage.endEditing()
        didChangeText()
        return true
    }

    // Show a pointing-hand cursor over rendered checkboxes so they read as
    // clickable, instead of the text I-beam.
    override func resetCursorRects() {
        super.resetCursorRects()
        guard let layoutManager, let textContainer, let textStorage else { return }
        let text = string as NSString
        let inset = textContainerOrigin
        textStorage.enumerateAttribute(
            .taskdownListMarker,
            in: NSRange(location: 0, length: textStorage.length),
            options: []
        ) { value, range, _ in
            guard let symbol = value as? String,
                  symbol == ListMarker.checked || symbol == ListMarker.unchecked
            else { return }
            let lineRange = text.lineRange(for: range)
            guard let marker = MarkdownTasks.marker(in: text, lineRange: lineRange) else { return }
            let glyphRange = layoutManager.glyphRange(forCharacterRange: marker.hitRange, actualCharacterRange: nil)
            var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            rect.origin.x += inset.x
            rect.origin.y += inset.y
            self.addCursorRect(rect, cursor: .pointingHand)
        }
    }
}

/// Plain-text editor with non-destructive Markdown live preview. Inactive lines
/// are styled (syntax hidden, headings colored, checkboxes drawn); the line the
/// cursor is on always shows its raw source. Clicking a checkbox toggles it.
struct MarkdownTextEditor: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat = 14
    var rendersMarkdown: Bool = true

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let contentSize = scrollView.contentSize
        let textStorage = NSTextStorage()
        let layoutManager = MarkdownLayoutManager()
        let textContainer = NSTextContainer(
            containerSize: NSSize(
                width: contentSize.width,
                height: CGFloat.greatestFiniteMagnitude
            )
        )
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        let textView = MarkdownTextView(
            frame: NSRect(origin: .zero, size: contentSize),
            textContainer: textContainer
        )
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = NSFont.systemFont(ofSize: fontSize)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.textContainerInset = NSSize(width: 5, height: 6)
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.containerSize = NSSize(
            width: contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        scrollView.documentView = textView

        context.coordinator.textView = textView
        context.coordinator.refreshAppearance()
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = context.coordinator.textView else { return }

        var needsAppearanceRefresh = context.coordinator.appearanceSettingsChanged(
            fontSize: fontSize,
            rendersMarkdown: rendersMarkdown
        )

        if textView.string != text {
            let selection = textView.selectedRange()
            context.coordinator.isUpdatingText = true
            textView.string = text
            textView.setSelectedRange(
                NSRange(
                    location: min(selection.location, (text as NSString).length),
                    length: 0
                )
            )
            context.coordinator.isUpdatingText = false
            needsAppearanceRefresh = true
        }

        if needsAppearanceRefresh {
            context.coordinator.refreshAppearance()
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownTextEditor
        weak var textView: MarkdownTextView?
        var isUpdatingText = false
        var isUpdatingAppearance = false
        private var lastFontSize: CGFloat?
        private var lastRendersMarkdown: Bool?

        init(parent: MarkdownTextEditor) {
            self.parent = parent
        }

        func appearanceSettingsChanged(fontSize: CGFloat, rendersMarkdown: Bool) -> Bool {
            defer {
                lastFontSize = fontSize
                lastRendersMarkdown = rendersMarkdown
            }
            return lastFontSize != fontSize || lastRendersMarkdown != rendersMarkdown
        }

        func textDidChange(_ notification: Notification) {
            guard let textView, !isUpdatingText, !isUpdatingAppearance else { return }
            parent.text = textView.string
            if parent.rendersMarkdown {
                refreshAppearance()
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard parent.rendersMarkdown else { return }
            refreshAppearance()
        }

        // Reveal the caret line when this field gains focus, and fully render
        // it again when focus leaves — so only the focused field ever shows raw
        // Markdown.
        func textDidBeginEditing(_ notification: Notification) {
            guard parent.rendersMarkdown else { return }
            refreshAppearance()
        }

        func textDidEndEditing(_ notification: Notification) {
            guard parent.rendersMarkdown else { return }
            refreshAppearance()
        }

        func refreshAppearance() {
            guard let textView,
                  let textStorage = textView.textStorage,
                  let layoutManager = textView.layoutManager
            else { return }
            let font = NSFont.systemFont(ofSize: parent.fontSize)
            textView.insertionPointColor = .textColor

            let text = textView.string as NSString
            // Only the focused field reveals its cursor line; unfocused fields
            // render every line so they read as finished Markdown.
            let isFocused = (textView.window?.firstResponder === textView)
            let activeRanges: [NSRange] = isFocused
                ? textView.selectedRanges.compactMap { value -> NSRange? in
                    let selection = value.rangeValue
                    guard selection.location <= text.length else { return nil }
                    return text.lineRange(for: selection)
                }
                : []
            isUpdatingAppearance = true
            MarkdownStyler.apply(
                to: textStorage,
                baseFont: font,
                activeLineRanges: activeRanges,
                enabled: parent.rendersMarkdown
            )
            layoutManager.invalidateDisplay(
                forCharacterRange: NSRange(location: 0, length: textStorage.length)
            )
            textView.typingAttributes = [
                .font: font,
                .foregroundColor: NSColor.textColor
            ]
            // Checkbox positions changed, so rebuild the pointing-hand cursor
            // rects.
            textView.window?.invalidateCursorRects(for: textView)
            isUpdatingAppearance = false
        }
    }
}

import AppKit

extension NSAttributedString.Key {
    static let taskdownListMarker = NSAttributedString.Key("TaskdownListMarker")
}

/// Applies non-destructive display attributes to plain Markdown text. Only
/// attributes change; the text storage string remains the original source.
/// Lines the cursor is on always show their raw source; every other line is
/// styled (syntax hidden, headings colored, checkboxes drawn).
///
/// Adapted from Notebloat's MarkdownStyler. Taskdown adds: the task checkbox
/// pattern is shared with `MarkdownTasks` (so counting and click-to-toggle
/// agree with what is drawn), and a completed task's text is dimmed and struck
/// through.
enum MarkdownStyler {
    private static let hiddenFont = NSFont.systemFont(ofSize: 0.1)
    private static let headingColors: [NSColor] = [
        color(red: 0x7E, green: 0xB8, blue: 0xDA),
        color(red: 0xE8, green: 0x8A, blue: 0x8A),
        color(red: 0xB3, green: 0x9D, blue: 0xDB),
        color(red: 0xA5, green: 0xD6, blue: 0xA7),
        color(red: 0xFF, green: 0xB8, blue: 0x6C),
        color(red: 0xF4, green: 0x8F, blue: 0xB1)
    ]

    private static let headingPattern = try! NSRegularExpression(
        pattern: "^(#{1,6})[\\t ]+(.+)$"
    )
    private static let boldPatterns = [
        try! NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*"),
        try! NSRegularExpression(pattern: "__(.+?)__")
    ]
    private static let italicPatterns = [
        try! NSRegularExpression(pattern: "(?<!\\*)\\*([^*\\n]+)\\*(?!\\*)"),
        try! NSRegularExpression(pattern: "(?<!_)_([^_\\n]+)_(?!_)")
    ]
    private static let strikethroughPattern = try! NSRegularExpression(
        pattern: "~~(.+?)~~"
    )
    private static let codePattern = try! NSRegularExpression(
        pattern: "`([^`\\n]+)`"
    )
    private static let linkPattern = try! NSRegularExpression(
        pattern: "\\[([^\\]]+)\\]\\(([^)]+)\\)"
    )
    private static let quotePattern = try! NSRegularExpression(
        pattern: "^[\\t ]*>[\\t ]?"
    )
    // The task checkbox pattern lives in MarkdownTasks so the renderer, the
    // counts, and click-to-toggle share one definition.
    private static var taskPattern: NSRegularExpression { MarkdownTasks.pattern }
    private static let unorderedListPattern = try! NSRegularExpression(
        pattern: "^([\\t ]*)([-+*])[\\t ]+"
    )
    private static let orderedListPattern = try! NSRegularExpression(
        pattern: "^[\\t ]*\\d+\\.[\\t ]+"
    )

    static func apply(
        to textStorage: NSTextStorage,
        baseFont: NSFont,
        activeLineRanges: [NSRange],
        enabled: Bool
    ) {
        let text = textStorage.string as NSString
        let fullRange = NSRange(location: 0, length: text.length)
        textStorage.beginEditing()
        defer { textStorage.endEditing() }

        guard text.length > 0 else { return }

        textStorage.setAttributes(
            [.font: baseFont, .foregroundColor: NSColor.textColor],
            range: fullRange
        )
        guard enabled else { return }

        var index = 0
        while index < text.length {
            var lineStart = 0
            var lineEnd = 0
            var contentsEnd = 0
            text.getLineStart(
                &lineStart,
                end: &lineEnd,
                contentsEnd: &contentsEnd,
                for: NSRange(location: index, length: 0)
            )

            let lineRange = NSRange(location: lineStart, length: contentsEnd - lineStart)
            if !activeLineRanges.contains(where: { rangesTouch($0, lineRange) }) {
                styleLine(
                    in: textStorage,
                    text: text,
                    range: lineRange,
                    baseFont: baseFont
                )
            }

            guard lineEnd > index else { break }
            index = lineEnd
        }
    }

    private static func styleLine(
        in textStorage: NSTextStorage,
        text: NSString,
        range: NSRange,
        baseFont: NSFont
    ) {
        let line = text.substring(with: range) as NSString
        let localRange = NSRange(location: 0, length: line.length)

        if let match = headingPattern.firstMatch(in: line as String, range: localRange) {
            let level = match.range(at: 1).length
            let contentRange = absolute(match.range(at: 2), within: range)
            let sizeIncrease: CGFloat = [6, 4, 2, 1, 0, 0][level - 1]
            let headingFont = NSFont.systemFont(
                ofSize: baseFont.pointSize + sizeIncrease,
                weight: .bold
            )
            textStorage.addAttributes(
                [
                    .font: headingFont,
                    .foregroundColor: headingColors[level - 1]
                ],
                range: contentRange
            )
            hide(
                NSRange(location: range.location, length: contentRange.location - range.location),
                in: textStorage
            )
        }

        styleDelimitedMatches(
            boldPatterns,
            in: line,
            lineRange: range,
            textStorage: textStorage,
            contentAttributes: [
                .font: NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
            ]
        )
        styleDelimitedMatches(
            italicPatterns,
            in: line,
            lineRange: range,
            textStorage: textStorage,
            contentAttributes: [
                .font: NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
            ]
        )
        styleDelimitedMatches(
            [strikethroughPattern],
            in: line,
            lineRange: range,
            textStorage: textStorage,
            contentAttributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue]
        )
        styleDelimitedMatches(
            [codePattern],
            in: line,
            lineRange: range,
            textStorage: textStorage,
            contentAttributes: [
                .font: NSFont.monospacedSystemFont(ofSize: baseFont.pointSize, weight: .regular),
                .backgroundColor: NSColor.quaternaryLabelColor
            ]
        )

        for match in linkPattern.matches(in: line as String, range: localRange) {
            let labelRange = absolute(match.range(at: 1), within: range)
            textStorage.addAttributes(
                [
                    .foregroundColor: NSColor.linkColor,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ],
                range: labelRange
            )
            hide(NSRange(location: range.location + match.range.location, length: 1), in: textStorage)
            let trailingStart = labelRange.location + labelRange.length
            let matchEnd = range.location + match.range.location + match.range.length
            hide(NSRange(location: trailingStart, length: matchEnd - trailingStart), in: textStorage)
        }

        if let match = taskPattern.firstMatch(in: line as String, range: localRange) {
            let checkedRange = match.range(at: 4)
            let checked = checkedRange.location != NSNotFound
                && checkedRange.length > 0
                && line.substring(with: checkedRange).lowercased() == "x"
            let r2 = match.range(at: 2)
            let symbolRange = r2.location != NSNotFound ? r2 : match.range(at: 3)
            renderTaskMarker(
                symbolLocalRange: symbolRange,
                matchRange: match.range,
                line: line,
                in: range,
                textStorage: textStorage,
                baseFont: baseFont,
                checked: checked
            )
            // Dim and strike through a completed task's text so done work reads
            // as done at a glance.
            if checked {
                let contentStart = range.location + match.range.length
                let contentRange = NSRange(
                    location: contentStart,
                    length: max(0, NSMaxRange(range) - contentStart)
                )
                if contentRange.length > 0 {
                    textStorage.addAttributes(
                        [
                            .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                            .foregroundColor: NSColor.secondaryLabelColor
                        ],
                        range: contentRange
                    )
                }
            }
        } else if let match = unorderedListPattern.firstMatch(in: line as String, range: localRange) {
            renderListMarker(
                match: match,
                symbolRange: match.range(at: 2),
                in: range,
                textStorage: textStorage,
                symbol: "•"
            )
        } else if let match = quotePattern.firstMatch(in: line as String, range: localRange) {
            let markerRange = absolute(match.range, within: range)
            hide(markerRange, in: textStorage)
            let contentRange = NSRange(
                location: markerRange.location + markerRange.length,
                length: max(0, NSMaxRange(range) - NSMaxRange(markerRange))
            )
            textStorage.addAttribute(
                .foregroundColor,
                value: NSColor.secondaryLabelColor,
                range: contentRange
            )
        } else if let match = orderedListPattern.firstMatch(in: line as String, range: localRange) {
            textStorage.addAttribute(
                .foregroundColor,
                value: NSColor.secondaryLabelColor,
                range: absolute(match.range, within: range)
            )
        }
    }

    /// Render a task checkbox. The marker syntax is hidden and a fixed-width
    /// "slot" is reserved with kerning on the symbol character, which is kept at
    /// the base font so the line keeps its normal height (even when the line is
    /// just an empty `[ ]`). The layout manager draws the box in that slot.
    private static func renderTaskMarker(
        symbolLocalRange: NSRange,
        matchRange: NSRange,
        line: NSString,
        in lineRange: NSRange,
        textStorage: NSTextStorage,
        baseFont: NSFont,
        checked: Bool
    ) {
        let symbolStart = symbolLocalRange.location
        let matchEnd = matchRange.location + matchRange.length

        // Collapse everything after the symbol character (keeps leading
        // indentation intact so nested tasks still indent).
        let afterSymbol = NSRange(
            location: symbolStart + 1,
            length: max(0, matchEnd - (symbolStart + 1))
        )
        if afterSymbol.length > 0 {
            hide(absolute(afterSymbol, within: lineRange), in: textStorage)
        }

        let symbolChar = line.substring(with: symbolLocalRange) as NSString
        let charWidth = symbolChar.size(withAttributes: [.font: baseFont]).width
        let slot = (baseFont.pointSize * 1.6).rounded() + 2
        let symbolAbs = absolute(NSRange(location: symbolStart, length: 1), within: lineRange)
        textStorage.addAttributes(
            [
                .font: baseFont,
                .foregroundColor: NSColor.clear,
                .kern: max(2, slot - charWidth),
                .taskdownListMarker: checked ? ListMarker.checked : ListMarker.unchecked
            ],
            range: symbolAbs
        )
    }

    private static func renderListMarker(
        match: NSTextCheckingResult,
        symbolRange: NSRange,
        in lineRange: NSRange,
        textStorage: NSTextStorage,
        symbol: String
    ) {
        // Make the entire match range invisible but keep the original font so
        // the characters preserve their natural widths. This ensures the content
        // text starts at its normal position after the full marker syntax (e.g.
        // "- ", "- [x] ") and the replacement symbol has proper spacing.
        let fullMatchRange = absolute(match.range, within: lineRange)
        textStorage.addAttribute(
            .foregroundColor,
            value: NSColor.clear,
            range: fullMatchRange
        )

        // Place the replacement symbol attribute on the marker character so the
        // custom layout manager draws it at the correct glyph position.
        let markerRange = absolute(symbolRange, within: lineRange)
        textStorage.addAttribute(
            .taskdownListMarker,
            value: symbol,
            range: markerRange
        )
    }

    private static func styleDelimitedMatches(
        _ patterns: [NSRegularExpression],
        in line: NSString,
        lineRange: NSRange,
        textStorage: NSTextStorage,
        contentAttributes: [NSAttributedString.Key: Any]
    ) {
        let localRange = NSRange(location: 0, length: line.length)
        for pattern in patterns {
            for match in pattern.matches(in: line as String, range: localRange) {
                let wholeRange = absolute(match.range, within: lineRange)
                let contentRange = absolute(match.range(at: 1), within: lineRange)
                textStorage.addAttributes(
                    contentAttributes,
                    range: contentRange
                )
                hide(
                    NSRange(location: wholeRange.location, length: contentRange.location - wholeRange.location),
                    in: textStorage
                )
                hide(
                    NSRange(
                        location: NSMaxRange(contentRange),
                        length: NSMaxRange(wholeRange) - NSMaxRange(contentRange)
                    ),
                    in: textStorage
                )
            }
        }
    }

    private static func hide(_ range: NSRange, in textStorage: NSTextStorage) {
        guard range.length > 0 else { return }
        textStorage.addAttributes(
            [.font: hiddenFont, .foregroundColor: NSColor.clear],
            range: range
        )
    }

    private static func absolute(_ localRange: NSRange, within lineRange: NSRange) -> NSRange {
        NSRange(location: lineRange.location + localRange.location, length: localRange.length)
    }

    private static func rangesTouch(_ left: NSRange, _ right: NSRange) -> Bool {
        if left.length == 0 {
            return left.location >= right.location && left.location <= NSMaxRange(right)
        }
        return NSIntersectionRange(left, right).length > 0
    }

    private static func color(red: Int, green: Int, blue: Int) -> NSColor {
        NSColor(
            srgbRed: CGFloat(red) / 255,
            green: CGFloat(green) / 255,
            blue: CGFloat(blue) / 255,
            alpha: 1
        )
    }
}

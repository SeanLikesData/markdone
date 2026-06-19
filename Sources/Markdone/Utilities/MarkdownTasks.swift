import Foundation

/// Shared logic for recognizing, counting, and toggling Markdown task
/// checkboxes. One regular expression is the single source of truth so the live
/// renderer, the completion counts, and click-to-toggle always agree on what a
/// checkbox is and where its brackets are.
enum MarkdownTasks {
    /// Matches a task checkbox at the start of a line, with optional indentation
    /// and an optional list bullet. Both the bare `[]` / `[ ]` form and the
    /// standard `- [ ]` form are accepted. A space (or end of line) must follow
    /// the closing bracket so that `[x]text` is not mistaken for a checkbox.
    ///
    /// Capture groups: 1 = indentation, 2 = bullet (optional), 3 = `[`,
    /// 4 = state character (a space, `x`, `X`, or empty).
    static let pattern = try! NSRegularExpression(
        pattern: "^([\\t ]*)(?:([-+*])[\\t ]+)?(\\[)([ xX]?)\\](?:[\\t ]+|$)"
    )

    /// Completed and total checkbox counts in a block of Markdown.
    static func counts(in markdown: String) -> (done: Int, total: Int) {
        var done = 0
        var total = 0
        markdown.enumerateLines { line, _ in
            let ns = line as NSString
            guard let match = pattern.firstMatch(
                in: line,
                range: NSRange(location: 0, length: ns.length)
            ) else { return }
            total += 1
            if isChecked(match: match, line: ns) { done += 1 }
        }
        return (done, total)
    }

    /// A task checkbox located on one line, in absolute (whole-document)
    /// character coordinates.
    struct Marker {
        /// The clickable region: from the first non-whitespace character through
        /// the end of the marker syntax (where the rendered box is drawn). Used
        /// to hit-test a click.
        let hitRange: NSRange
        /// The `[ ]` / `[x]` / `[]` span, brackets included. Replaced on toggle.
        let bracketRange: NSRange
        let checked: Bool
        /// The text the bracket span should become when toggled.
        var toggledReplacement: String { checked ? "[ ]" : "[x]" }
    }

    /// Find the task checkbox on the line that contains `lineRange`, if any.
    /// `lineRange` is an absolute line range from `NSString.lineRange(for:)`.
    static func marker(in text: NSString, lineRange: NSRange) -> Marker? {
        let line = text.substring(with: lineRange) as NSString
        guard let match = pattern.firstMatch(
            in: line as String,
            range: NSRange(location: 0, length: line.length)
        ) else { return nil }

        let indentLength = match.range(at: 1).length
        let hitStart = lineRange.location + indentLength
        let hitEnd = lineRange.location + match.range.location + match.range.length
        let hitRange = NSRange(location: hitStart, length: max(0, hitEnd - hitStart))

        let openBracket = match.range(at: 3)
        let state = match.range(at: 4)
        // The closing ']' sits immediately after the state character (or after
        // '[' when the state is empty, as in "[]").
        let closeBracketIndex = state.length > 0 ? NSMaxRange(state) : NSMaxRange(openBracket)
        let bracketLocal = NSRange(
            location: openBracket.location,
            length: closeBracketIndex + 1 - openBracket.location
        )
        let bracketRange = NSRange(
            location: lineRange.location + bracketLocal.location,
            length: bracketLocal.length
        )

        return Marker(
            hitRange: hitRange,
            bracketRange: bracketRange,
            checked: isChecked(match: match, line: line)
        )
    }

    private static func isChecked(match: NSTextCheckingResult, line: NSString) -> Bool {
        let state = match.range(at: 4)
        guard state.location != NSNotFound, state.length > 0 else { return false }
        return line.substring(with: state).lowercased() == "x"
    }
}

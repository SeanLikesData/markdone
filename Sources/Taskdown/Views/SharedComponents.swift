import SwiftUI

/// A labelled Markdown editing region: a small caption above a rounded,
/// frosted text field that live-renders Markdown. The building block every
/// task region (Big Three, This Week, each day, and the template editor) is
/// made of.
struct MarkdownField: View {
    var title: String? = nil
    let text: Binding<String>
    var fontSize: CGFloat = 14
    /// Forces the underlying editor to be recreated when this value changes, so
    /// switching days swaps content cleanly instead of reusing one editor.
    var resetID: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Style.secondaryText)
            }
            editor
                .background(
                    RoundedRectangle(cornerRadius: Style.rowCorner, style: .continuous)
                        .fill(Style.rowFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Style.rowCorner, style: .continuous)
                        .strokeBorder(Style.divider, lineWidth: 1)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var editor: some View {
        let view = MarkdownTextEditor(text: text, fontSize: fontSize, rendersMarkdown: true)
        if let resetID {
            view.id(resetID)
        } else {
            view
        }
    }
}

import SwiftUI

/// A panel section title with an optional add button on the right. The add
/// button shows a "+" and the keyboard letter that triggers the same action
/// (for example "W" for a new This Week task).
struct SectionHeader: View {
    let title: String
    var keyLetter: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(Style.primaryText)
            Spacer()
            if let keyLetter, let action {
                AddButton(keyLetter: keyLetter, action: action)
            }
        }
    }
}

/// The "+ X" pill button: a plus glyph and a keyboard-shortcut letter.
struct AddButton: View {
    let keyLetter: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                Text(keyLetter)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(Style.primaryText)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Style.chipFill)
            )
            .overlay(Capsule().strokeBorder(Style.divider, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help("Add (\(keyLetter))")
    }
}

/// A small label sub-header inside a section, such as "Big Three".
struct SubHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(Style.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

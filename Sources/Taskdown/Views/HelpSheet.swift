import SwiftUI

/// A reference sheet listing every keyboard shortcut.
struct HelpSheet: View {
    @EnvironmentObject var store: WeekStore

    private let shortcuts: [(String, String)] = [
        ("↑ / ↓", "Move within a column; Up from the top jumps to the day tabs"),
        ("← / →", "Move between the This Week and Tasks columns"),
        ("On the habits row: ← / →", "Move between habit checkboxes"),
        ("On day tabs: ← / →", "Switch the active day (Down returns to the column)"),
        ("Tab / ⇧Tab", "Cycle region: Day tabs → This Week → Tasks"),
        ("⇧← / ⇧→", "Move the selected task across days (This Week ↔ Mon…Sun)"),
        ("⇧↑ / ⇧↓", "Reorder the selected task within its list"),
        ("Space", "Toggle the selected task or habit complete"),
        ("Return or R", "Rename the selected task (double-click also works)"),
        ("While editing: ↑ / ↓", "Accept the text and move to the task above/below"),
        ("W", "New This Week task"),
        ("N", "New task in the selected day"),
        ("Delete", "Delete the selected task (clears a Big Three slot)"),
        ("⌘N", "New week"),
        ("T", "Open the weekly template"),
        ("?", "Show this shortcuts list"),
        ("Esc", "Cancel a rename, or close the popover")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Style.primaryText)
                Spacer()
                Button("Done") { store.activeSheet = nil }
                    .buttonStyle(SheetButtonStyle(prominent: true))
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(shortcuts.enumerated()), id: \.offset) { _, pair in
                        HStack(alignment: .top, spacing: 16) {
                            Text(pair.0)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(Style.primaryText)
                                .frame(width: 110, alignment: .leading)
                            Text(pair.1)
                                .font(.system(size: 13))
                                .foregroundColor(Style.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 9)
                        .overlay(
                            Rectangle().fill(Style.divider).frame(height: 1),
                            alignment: .bottom
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
        .frame(width: 520, height: 540)
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow)
                Color.black.opacity(0.30)
            }
        )
        .preferredColorScheme(.dark)
    }
}

import SwiftUI

/// A short reference sheet: how Markdown editing works, plus the app-level
/// keyboard shortcuts.
struct HelpSheet: View {
    @EnvironmentObject var store: WeekStore

    private let basics: [(String, String)] = [
        ("Checkboxes", "Type \"[] task\" or \"- [ ] task\" to make a checkbox. Click the box to mark it done; the text dims and strikes through."),
        ("Live Markdown", "Headings (#), bold (**), italic (*), lists (-), and links render in place. The line your cursor is on always shows its raw Markdown."),
        ("Day blocks", "Each day is its own Markdown block. Write tasks and notes freely; switch days with the tabs above."),
        ("Templates", "The weekly template seeds each new week. Open it from the bottom bar to set recurring tasks per day.")
    ]

    private let shortcuts: [(String, String)] = [
        ("⌘1 … ⌘7", "Jump to Monday … Sunday"),
        ("⌘⌥← / ⌘⌥→", "Previous / next day"),
        ("⌘N", "New week"),
        ("⌘W", "Close the popover"),
        ("Esc", "Close an open panel (template, settings, help)")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Help")
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
                VStack(alignment: .leading, spacing: 20) {
                    section("Basics", rows: basics, labelWidth: 110)
                    section("Keyboard Shortcuts", rows: shortcuts, labelWidth: 110)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
        .frame(width: 540, height: 560)
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow)
                Color.black.opacity(0.30)
            }
        )
        .preferredColorScheme(.dark)
    }

    private func section(_ title: String, rows: [(String, String)], labelWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Style.primaryText)
                .padding(.bottom, 8)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, pair in
                HStack(alignment: .top, spacing: 16) {
                    Text(pair.0)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Style.primaryText)
                        .frame(width: labelWidth, alignment: .leading)
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
    }
}

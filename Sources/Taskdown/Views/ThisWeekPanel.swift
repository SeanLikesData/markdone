import SwiftUI

/// The left column: the per-week Big Three priorities and the undated This Week
/// tasks, each a live-rendering Markdown field. Big Three is a compact block at
/// the top; This Week fills the remaining height.
struct LeftColumn: View {
    @EnvironmentObject var store: WeekStore
    @AppStorage(SettingsKey.fontSize) private var fontSize: Double = defaultFontSize

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            MarkdownField(
                title: "Big Three",
                text: store.bigThreeBinding(),
                fontSize: fontSize,
                resetID: "bigthree-\(store.selectedWeekID)"
            )
            .frame(height: 150)

            MarkdownField(
                title: "This Week",
                text: store.weekTasksBinding(),
                fontSize: fontSize,
                resetID: "thisweek-\(store.selectedWeekID)"
            )
            .frame(maxHeight: .infinity)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

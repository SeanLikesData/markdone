import SwiftUI

/// The day panel: the active day's name and a single live-rendering Markdown
/// field holding that day's tasks and notes. Switching the day tab swaps which
/// day's field is shown, so there is never a long file to scroll.
struct DayPanel: View {
    @EnvironmentObject var store: WeekStore
    @AppStorage(SettingsKey.fontSize) private var fontSize: Double = defaultFontSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.activeDay.fullName)
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(Style.primaryText)

            MarkdownField(
                text: store.dayBinding(store.activeDay),
                fontSize: fontSize,
                resetID: "day-\(store.selectedWeekID)-\(store.activeDay.rawValue)"
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

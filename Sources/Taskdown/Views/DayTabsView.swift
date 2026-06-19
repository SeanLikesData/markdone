import SwiftUI

/// The row of seven day tabs. The active day drives the day panel. Each tab
/// shows the count of completed checkboxes for that day (omitted when zero).
struct DayTabsView: View {
    @EnvironmentObject var store: WeekStore

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Weekday.allCases) { day in
                tab(day)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private func tab(_ day: Weekday) -> some View {
        let isActive = store.activeDay == day
        let completed = store.completedTaskCount(day)

        return HStack(spacing: 7) {
            Text(day.shortLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isActive ? Style.primaryText : Style.secondaryText)

            if completed > 0 {
                Text("\(completed)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Style.secondaryText)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isActive ? Style.selectionFill : Style.rowFill)
        )
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .onTapGesture { store.selectTab(day) }
    }
}

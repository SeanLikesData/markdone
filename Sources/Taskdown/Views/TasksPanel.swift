import SwiftUI

/// The right panel: the active day's habit checkboxes (seeded from the
/// template, completed independently each day) followed by that day's tasks.
struct TasksPanel: View {
    @EnvironmentObject var store: WeekStore

    private var day: DayPlan? {
        store.currentWeek?.day(store.activeDay)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Tasks", keyLetter: "N") {
                store.addDayTask()
            }

            if let day {
                if !day.habits.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(day.habits) { habit in
                            HabitChip(
                                item: habit,
                                isSelected: store.region == .tasks && store.selectedID == habit.id,
                                onToggle: { store.toggleDone(habit.id) },
                                onSelect: {
                                    store.region = .tasks
                                    store.selectedID = habit.id
                                }
                            )
                        }
                    }
                }

                VStack(spacing: 8) {
                    ForEach(day.tasks) { item in
                        TaskRow(
                            item: item,
                            placeholder: "New task",
                            markerStyle: .circle,
                            isSelected: store.region == .tasks && store.selectedID == item.id,
                            isEditing: store.editingID == item.id,
                            showMenu: true,
                            draft: $store.draftText,
                            onToggle: { store.toggleDone(item.id) },
                            onSelect: {
                                store.region = .tasks
                                store.selectedID = item.id
                            },
                            onBeginEdit: { store.beginEditing(item.id) },
                            onCommit: { store.commitEditing() },
                            onDelete: {
                                store.selectedID = item.id
                                store.deleteSelected()
                            },
                            onMove: { store.moveItem(item.id, toPosition: $0) }
                        )
                    }
                }

                if day.habits.isEmpty && day.tasks.isEmpty {
                    Text("No tasks for \(store.activeDay.shortLabel). Press N to add one.")
                        .font(.system(size: 13))
                        .foregroundColor(Style.mutedText)
                        .padding(.top, 6)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

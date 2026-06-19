import SwiftUI

/// The left panel: the per-week Big Three slots and the undated This Week
/// tasks. This Week tasks are the ones with no specific day yet; push them
/// into a day with Shift+Right or the row "Move to" menu.
struct ThisWeekPanel: View {
    @EnvironmentObject var store: WeekStore

    private var week: Week? { store.currentWeek }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "This Week", keyLetter: "W") {
                store.addWeekTask()
            }

            if let week {
                SubHeader(title: "Big Three")

                VStack(spacing: 8) {
                    ForEach(Array(week.bigThree.enumerated()), id: \.element.id) { index, item in
                        row(item, placeholder: "Big task \(index + 1)", showMenu: false)
                    }
                }

                if !week.weekTasks.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(week.weekTasks) { item in
                            row(item, placeholder: "New task", showMenu: true)
                        }
                    }
                    .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func row(_ item: TaskItem, placeholder: String, showMenu: Bool) -> some View {
        TaskRow(
            item: item,
            placeholder: placeholder,
            markerStyle: .circle,
            isSelected: store.region == .thisWeek && store.selectedID == item.id,
            isEditing: store.editingID == item.id,
            showMenu: showMenu,
            draft: $store.draftText,
            onToggle: { store.toggleDone(item.id) },
            onSelect: {
                store.region = .thisWeek
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

import SwiftUI

/// The bottom bar: saved-week count on the left; save status, Template, help,
/// and settings on the right.
struct BottomBar: View {
    @EnvironmentObject var store: WeekStore

    var body: some View {
        HStack(spacing: 10) {
            weekPill
            newWeekButton

            Spacer()

            Text(store.saveStateLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Style.secondaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(Style.chipFill))

            iconButton(systemName: "macwindow", title: nil) {
                store.onOpenInWindow?()
            }

            iconButton(systemName: "square.grid.2x2", title: "Template") {
                store.activeSheet = .template
            }

            iconButton(systemName: "questionmark", title: nil) {
                store.activeSheet = .help
            }

            iconButton(systemName: "gearshape", title: nil) {
                store.activeSheet = .settings
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    /// The current week label; tapping it opens the Weeks management panel.
    private var weekPill: some View {
        Button(action: { store.activeSheet = .weeks }) {
            HStack(spacing: 8) {
                Text(weekLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Style.primaryText)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Style.secondaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(Style.chipFill))
            .overlay(Capsule().strokeBorder(Style.divider, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help("Manage weeks")
    }

    private var newWeekButton: some View {
        Button(action: { store.addNewWeek() }) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                Text("New Week")
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(Style.primaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(Style.chipFill))
            .overlay(Capsule().strokeBorder(Style.divider, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help("Create a new week (⌘N)")
    }

    private var weekLabel: String {
        guard let week = store.currentWeek else { return "No week" }
        let counts = week.completion
        return "\(WeekMath.weekLabel(for: week.weekStart)) · \(counts.done)/\(counts.total)"
    }

    private func iconButton(systemName: String, title: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemName)
                    .font(.system(size: 13, weight: .medium))
                if let title {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                }
            }
            .foregroundColor(Style.primaryText)
            .padding(.horizontal, title == nil ? 9 : 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(Style.chipFill))
            .overlay(Capsule().strokeBorder(Style.divider, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

extension WeekStore {
    var saveStateLabel: String {
        switch saveState {
        case .saved: return "Saved"
        case .saving: return "Saving…"
        case .failed: return "Save failed"
        }
    }
}

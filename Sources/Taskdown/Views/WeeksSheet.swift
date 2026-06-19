import SwiftUI

/// The Weeks management panel: lists every saved week, lets you switch to one,
/// delete individual weeks, or clear them all. Opened from the week pill in the
/// bottom bar.
struct WeeksSheet: View {
    @EnvironmentObject var store: WeekStore
    @State private var confirmingDeleteAll = false

    private var weeks: [Week] { store.weeksSorted }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weeks")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Style.primaryText)
                    Text("\(weeks.count) saved week\(weeks.count == 1 ? "" : "s")")
                        .font(.system(size: 12))
                        .foregroundColor(Style.secondaryText)
                }
                Spacer()
                Button(action: { store.addNewWeek() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("New Week")
                    }
                }
                .buttonStyle(SheetButtonStyle())
                Button("Done") { store.activeSheet = nil }
                    .buttonStyle(SheetButtonStyle(prominent: true))
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(weeks) { week in
                        row(week)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }

            Rectangle().fill(Style.divider).frame(height: 1)

            HStack {
                Spacer()
                Button(role: .destructive, action: { confirmingDeleteAll = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("Delete all weeks")
                    }
                }
                .buttonStyle(SheetButtonStyle())
                .disabled(weeks.count <= 1)
                .confirmationDialog("Delete all weeks?", isPresented: $confirmingDeleteAll) {
                    Button("Delete All", role: .destructive) { store.deleteAllWeeks() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This removes every saved week and starts a fresh current week. This cannot be undone.")
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .frame(width: 520, height: 560)
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow)
                Color.black.opacity(0.30)
            }
        )
        .preferredColorScheme(.dark)
    }

    private func row(_ week: Week) -> some View {
        let isCurrent = week.id == store.selectedWeekID
        let counts = week.completion
        return HStack(spacing: 12) {
            Circle()
                .fill(isCurrent ? Style.accent : Color.clear)
                .overlay(Circle().strokeBorder(isCurrent ? Color.clear : Style.secondaryText, lineWidth: 1.5))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(WeekMath.weekLabel(for: week.weekStart))
                    .font(.system(size: 14, weight: isCurrent ? .semibold : .regular))
                    .foregroundColor(Style.primaryText)
                Text("\(counts.done)/\(counts.total) complete")
                    .font(.system(size: 12))
                    .foregroundColor(Style.secondaryText)
            }

            Spacer(minLength: 8)

            if isCurrent {
                Text("Current")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Style.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Style.chipFill))
            }

            Button(role: .destructive, action: { store.deleteWeek(week.id) }) {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundColor(Style.secondaryText)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Style.chipFill))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Delete this week")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: Style.rowCorner, style: .continuous)
                .fill(isCurrent ? Style.selectionFill : Style.rowFill)
        )
        .contentShape(RoundedRectangle(cornerRadius: Style.rowCorner, style: .continuous))
        .onTapGesture {
            store.openWeek(week.id)
            store.activeSheet = nil
        }
    }
}

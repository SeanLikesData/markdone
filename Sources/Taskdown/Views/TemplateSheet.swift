import SwiftUI

/// An editable row backing a single template name. Has identity so it can be
/// listed and focused while typing.
private struct EditRow: Identifiable {
    let id = UUID()
    var text: String
}

/// The Weekly Template editor. Edits a local copy and writes it back only on
/// Save, so Cancel discards. Template changes apply to new weeks only; Big
/// Three is per-week and is not part of the template.
struct TemplateSheet: View {
    @EnvironmentObject var store: WeekStore

    @State private var habits: [EditRow] = []
    @State private var weekTasks: [EditRow] = []
    @State private var dayTasks: [Int: [EditRow]] = [:]
    @State private var selectedDay: Weekday = .monday
    @FocusState private var focusedRow: UUID?

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                HStack(alignment: .top, spacing: 0) {
                    leftColumn
                        .frame(maxWidth: .infinity, alignment: .topLeading)

                    Rectangle().fill(Style.divider).frame(width: 1)

                    rightColumn
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .padding(24)
            }
        }
        .frame(width: 780, height: 660)
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow)
                Color.black.opacity(0.30)
            }
        )
        .preferredColorScheme(.dark)
        .onAppear(perform: loadFromTemplate)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Weekly Template")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Style.primaryText)
                Spacer()
                Button("Cancel") { store.activeSheet = nil }
                    .buttonStyle(SheetButtonStyle())
                Button("Save") { saveAndClose() }
                    .buttonStyle(SheetButtonStyle(prominent: true))
            }
            Text("Template changes apply to new weeks only. Big Three items are set separately for each week.")
                .font(.system(size: 13))
                .foregroundColor(Style.secondaryText)
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 16)
    }

    // MARK: - Left column

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Daily Habits", keyLetter: "H") {
                    let row = EditRow(text: "")
                    habits.append(row)
                    focusedRow = row.id
                }
                ForEach($habits) { $row in
                    editRow($row, markerStyle: .checkbox) {
                        habits.removeAll { $0.id == row.id }
                    }
                }
            }

            Rectangle().fill(Style.divider).frame(height: 1)

            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "This Week", keyLetter: "W") {
                    let row = EditRow(text: "")
                    weekTasks.append(row)
                    focusedRow = row.id
                }
                ForEach($weekTasks) { $row in
                    editRow($row, markerStyle: .circle) {
                        weekTasks.removeAll { $0.id == row.id }
                    }
                }
            }
        }
        .padding(.trailing, 24)
    }

    // MARK: - Right column

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Tasks", keyLetter: "N") {
                let row = EditRow(text: "")
                dayTasks[selectedDay.rawValue, default: []].append(row)
                focusedRow = row.id
            }

            HStack(spacing: 6) {
                ForEach(Weekday.allCases) { day in
                    dayTab(day)
                }
            }

            ForEach(bindingForDay(selectedDay)) { $row in
                editRow($row, markerStyle: .circle) {
                    dayTasks[selectedDay.rawValue]?.removeAll { $0.id == row.id }
                }
            }
        }
        .padding(.leading, 24)
    }

    private func dayTab(_ day: Weekday) -> some View {
        let isActive = selectedDay == day
        return Text(String(day.shortLabel.prefix(1)))
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(isActive ? Style.primaryText : Style.secondaryText)
            .frame(minWidth: 16)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isActive ? Style.selectionFill : Style.rowFill)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture { selectedDay = day }
    }

    // MARK: - Editable row

    private func editRow(_ row: Binding<EditRow>, markerStyle: MarkerStyle, onDelete: @escaping () -> Void) -> some View {
        HStack(spacing: 11) {
            Marker(style: markerStyle, done: false)
            TextField("New item", text: row.text)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundColor(Style.primaryText)
                .focused($focusedRow, equals: row.wrappedValue.id)
            Spacer(minLength: 4)
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Style.secondaryText)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Style.rowHPadding)
        .padding(.vertical, Style.rowVPadding)
        .background(
            RoundedRectangle(cornerRadius: Style.rowCorner, style: .continuous)
                .fill(Style.rowFill)
        )
    }

    private func bindingForDay(_ day: Weekday) -> Binding<[EditRow]> {
        Binding(
            get: { dayTasks[day.rawValue] ?? [] },
            set: { dayTasks[day.rawValue] = $0 }
        )
    }

    // MARK: - Load and save

    private func loadFromTemplate() {
        let template = store.template
        habits = template.habits.map { EditRow(text: $0) }
        weekTasks = template.weekTasks.map { EditRow(text: $0) }
        var byDay: [Int: [EditRow]] = [:]
        for day in Weekday.allCases {
            byDay[day.rawValue] = template.tasks(for: day).map { EditRow(text: $0) }
        }
        dayTasks = byDay
    }

    private func saveAndClose() {
        var template = Template()
        template.habits = habits.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        template.weekTasks = weekTasks.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        var byDay: [Int: [String]] = [:]
        for day in Weekday.allCases {
            let names = (dayTasks[day.rawValue] ?? [])
                .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if !names.isEmpty { byDay[day.rawValue] = names }
        }
        template.dayTasks = byDay
        store.saveTemplate(template)
        store.activeSheet = nil
    }
}

/// Pill button style for sheet headers.
struct SheetButtonStyle: ButtonStyle {
    var prominent: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Style.primaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(prominent ? Color.white.opacity(0.20) : Style.chipFill)
            )
            .overlay(Capsule().strokeBorder(Style.divider, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

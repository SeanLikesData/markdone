import SwiftUI

/// The Weekly Template editor. Each region is a Markdown block that seeds the
/// matching block of every new week. Edits a local copy and writes it back only
/// on Save, so Cancel discards.
struct TemplateSheet: View {
    @EnvironmentObject var store: WeekStore
    @AppStorage(SettingsKey.fontSize) private var fontSize: Double = defaultFontSize

    @State private var bigThree: String = ""
    @State private var weekTasks: String = ""
    @State private var dayMarkdown: [Int: String] = [:]
    @State private var selectedDay: Weekday = .monday

    var body: some View {
        VStack(spacing: 0) {
            header

            HStack(alignment: .top, spacing: 0) {
                leftColumn
                    .frame(width: 320)

                Rectangle().fill(Style.divider).frame(width: 1)

                rightColumn
                    .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
        .frame(width: 820, height: 660)
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
            Text("Template blocks seed every new week. Write tasks with checkboxes like \"[ ] task\". Changes apply to new weeks only.")
                .font(.system(size: 13))
                .foregroundColor(Style.secondaryText)
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 10)
    }

    // MARK: - Left column

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            MarkdownField(title: "Big Three", text: $bigThree, fontSize: fontSize)
                .frame(height: 150)
            MarkdownField(title: "This Week", text: $weekTasks, fontSize: fontSize)
                .frame(maxHeight: .infinity)
        }
        .padding(.trailing, 20)
    }

    // MARK: - Right column

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                ForEach(Weekday.allCases) { day in
                    dayTab(day)
                }
            }

            MarkdownField(
                title: selectedDay.fullName,
                text: bindingForDay(selectedDay),
                fontSize: fontSize,
                resetID: "template-day-\(selectedDay.rawValue)"
            )
            .frame(maxHeight: .infinity)
        }
        .padding(.leading, 20)
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

    private func bindingForDay(_ day: Weekday) -> Binding<String> {
        Binding(
            get: { dayMarkdown[day.rawValue] ?? "" },
            set: { dayMarkdown[day.rawValue] = $0 }
        )
    }

    // MARK: - Load and save

    private func loadFromTemplate() {
        let template = store.template
        bigThree = template.bigThreeMarkdown
        weekTasks = template.weekTasksMarkdown
        var byDay: [Int: String] = [:]
        for day in Weekday.allCases {
            byDay[day.rawValue] = template.markdown(for: day)
        }
        dayMarkdown = byDay
    }

    private func saveAndClose() {
        var template = Template()
        template.bigThreeMarkdown = bigThree
        template.weekTasksMarkdown = weekTasks
        var byDay: [Int: String] = [:]
        for day in Weekday.allCases {
            let markdown = dayMarkdown[day.rawValue] ?? ""
            if !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                byDay[day.rawValue] = markdown
            }
        }
        template.dayMarkdown = byDay
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

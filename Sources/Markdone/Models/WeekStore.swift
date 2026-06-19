import SwiftUI
import AppKit
import os

/// Which modal sheet, if any, is open over the main content.
enum ActiveSheet: Identifiable {
    case weeks
    case template
    case settings
    case help
    var id: Int {
        switch self {
        case .weeks: return 0
        case .template: return 1
        case .settings: return 2
        case .help: return 3
        }
    }
}

enum SaveState {
    case saved
    case saving
    case failed
}

/// The single source of truth: all saved weeks, the template, the current week
/// and day selection, and local persistence. Every task region is a Markdown
/// string edited directly in a text field; the store exposes a `Binding` to each
/// and saves on change.
@MainActor
final class WeekStore: ObservableObject {
    @Published private(set) var data = MarkdoneData()
    @Published var selectedWeekID: UUID = UUID()
    @Published var activeDay: Weekday = .monday

    @Published var activeSheet: ActiveSheet?
    @Published private(set) var saveState: SaveState = .saved

    /// Closure the AppDelegate sets so Escape can close the popover.
    var onRequestClose: (() -> Void)?
    /// Closure the AppDelegate sets so the bottom bar can pop out into a
    /// resizable window.
    var onOpenInWindow: (() -> Void)?

    private let logger = Logger(subsystem: "com.markdone.app", category: "store")
    private var saveWorkItem: DispatchWorkItem?

    // MARK: - Persistence paths

    private var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Markdone", isDirectory: true)
    }

    private var dataURL: URL {
        supportDirectory.appendingPathComponent("data.json")
    }

    /// The data file under the app's former name ("Taskdown"), copied to the
    /// current location on first launch after the rename.
    private var legacyDataURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Taskdown", isDirectory: true)
            .appendingPathComponent("data.json")
    }

    // MARK: - Lifecycle

    init() {
        migrateLegacyDataIfNeeded()
        load()
        ensureSomeWeek()
    }

    /// One-time move from the old "Taskdown" support directory. Copies (rather
    /// than moves) so the original stays as a backup.
    private func migrateLegacyDataIfNeeded() {
        let newURL = dataURL
        let oldURL = legacyDataURL
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: newURL.path),
              fileManager.fileExists(atPath: oldURL.path) else { return }
        do {
            try fileManager.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
            try fileManager.copyItem(at: oldURL, to: newURL)
            logger.info("Migrated data from the former Taskdown location")
        } catch {
            logger.error("Failed to migrate legacy data: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func load() {
        let url = dataURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let bytes = try Data(contentsOf: url)
            data = try JSONDecoder().decode(MarkdoneData.self, from: bytes)
        } catch {
            logger.error("Failed to load data: \(error.localizedDescription, privacy: .public)")
            // Preserve the unreadable file so the fresh week we are about to
            // create and save never silently destroys recoverable data.
            backUpUnreadableFile(at: url)
        }
    }

    private func backUpUnreadableFile(at url: URL) {
        let timestamp = Int(Date().timeIntervalSince1970)
        let backup = url.deletingLastPathComponent()
            .appendingPathComponent("data-unreadable-\(timestamp).json")
        try? FileManager.default.copyItem(at: url, to: backup)
        logger.error("Backed up unreadable data to \(backup.lastPathComponent, privacy: .public)")
    }

    /// Make sure at least the current calendar week exists, and select a week
    /// and the day that matches today.
    private func ensureSomeWeek() {
        let thisMonday = WeekMath.mondayOfWeek(containing: Date())
        if data.weeks.isEmpty {
            data.weeks.append(seededWeek(monday: thisMonday))
            scheduleSave()
        }
        let sorted = weeksSorted
        if let current = sorted.first(where: { $0.weekStart == thisMonday }) {
            selectedWeekID = current.id
        } else if let latest = sorted.last {
            selectedWeekID = latest.id
        }
        if currentWeek?.weekStart == thisMonday {
            activeDay = weekdayOfToday()
        } else {
            activeDay = .monday
        }
    }

    private func weekdayOfToday() -> Weekday {
        let weekdayNumber = WeekMath.calendar.component(.weekday, from: Date()) // 1=Sun...7=Sat
        let index = (weekdayNumber + 5) % 7 // Monday = 0
        return Weekday(rawValue: index) ?? .monday
    }

    // MARK: - Derived

    var weeksSorted: [Week] {
        data.weeks.sorted { $0.weekStart < $1.weekStart }
    }

    var currentWeek: Week? {
        data.weeks.first { $0.id == selectedWeekID }
    }

    var template: Template { data.template }

    /// Index of the selected week within the chronological list, for the picker.
    var currentWeekOrdinal: (index: Int, count: Int)? {
        let sorted = weeksSorted
        guard let idx = sorted.firstIndex(where: { $0.id == selectedWeekID }) else { return nil }
        return (idx, sorted.count)
    }

    // MARK: - Week navigation and management

    private func selectWeek(_ week: Week) {
        selectedWeekID = week.id
        activeDay = .monday
    }

    /// Switch to a week by id (used by the Weeks panel).
    func openWeek(_ id: UUID) {
        guard let week = data.weeks.first(where: { $0.id == id }) else { return }
        selectWeek(week)
    }

    /// Create the week after the latest saved week, seeded from the template.
    func addNewWeek() {
        let sorted = weeksSorted
        let nextMonday: Date
        if let latest = sorted.last {
            nextMonday = WeekMath.nextMonday(after: latest.weekStart)
        } else {
            nextMonday = WeekMath.mondayOfWeek(containing: Date())
        }
        if let existing = data.weeks.first(where: { $0.weekStart == nextMonday }) {
            selectWeek(existing)
            return
        }
        let week = seededWeek(monday: nextMonday)
        data.weeks.append(week)
        selectWeek(week)
        scheduleSave()
    }

    /// Delete a specific week by id. If it was the selected week, a neighbor is
    /// selected. If it was the last remaining week, the current calendar week is
    /// recreated so there is always at least one week.
    func deleteWeek(_ id: UUID) {
        let sorted = weeksSorted
        guard let idx = sorted.firstIndex(where: { $0.id == id }) else { return }
        let wasSelected = (id == selectedWeekID)
        data.weeks.removeAll { $0.id == id }

        if data.weeks.isEmpty {
            let monday = WeekMath.mondayOfWeek(containing: Date())
            let week = seededWeek(monday: monday)
            data.weeks.append(week)
            selectWeek(week)
        } else if wasSelected {
            let newSorted = weeksSorted
            selectWeek(newSorted[min(idx, newSorted.count - 1)])
        }
        scheduleSave()
    }

    /// Remove every week and recreate the current calendar week.
    func deleteAllWeeks() {
        data.weeks.removeAll()
        let monday = WeekMath.mondayOfWeek(containing: Date())
        let week = seededWeek(monday: monday)
        data.weeks.append(week)
        selectWeek(week)
        scheduleSave()
    }

    /// Build a new week from the template: each block seeded from the matching
    /// template block.
    private func seededWeek(monday: Date) -> Week {
        var week = Week(weekStart: monday)
        week.bigThreeMarkdown = data.template.bigThreeMarkdown
        week.weekTasksMarkdown = data.template.weekTasksMarkdown
        week.days = Weekday.allCases.map { weekday in
            DayPlan(weekday: weekday, markdown: data.template.markdown(for: weekday))
        }
        return week
    }

    // MARK: - Editing the current week's Markdown

    private func withCurrentWeek(_ mutate: (inout Week) -> Void) {
        guard let i = data.weeks.firstIndex(where: { $0.id == selectedWeekID }) else { return }
        mutate(&data.weeks[i])
        scheduleSave()
    }

    func setBigThreeMarkdown(_ value: String) {
        withCurrentWeek { $0.bigThreeMarkdown = value }
    }

    func setWeekTasksMarkdown(_ value: String) {
        withCurrentWeek { $0.weekTasksMarkdown = value }
    }

    func setDayMarkdown(_ weekday: Weekday, _ value: String) {
        withCurrentWeek { week in
            if let d = week.days.firstIndex(where: { $0.weekday == weekday }) {
                week.days[d].markdown = value
            }
        }
    }

    /// `Binding`s the Markdown fields edit through. Reading falls back to an
    /// empty string when no week is selected, which should not happen in
    /// practice because `init` always selects one.
    func bigThreeBinding() -> Binding<String> {
        Binding(
            get: { self.currentWeek?.bigThreeMarkdown ?? "" },
            set: { self.setBigThreeMarkdown($0) }
        )
    }

    func weekTasksBinding() -> Binding<String> {
        Binding(
            get: { self.currentWeek?.weekTasksMarkdown ?? "" },
            set: { self.setWeekTasksMarkdown($0) }
        )
    }

    func dayBinding(_ weekday: Weekday) -> Binding<String> {
        Binding(
            get: { self.currentWeek?.day(weekday).markdown ?? "" },
            set: { self.setDayMarkdown(weekday, $0) }
        )
    }

    // MARK: - Day selection

    func switchDay(forward: Bool) {
        let next = activeDay.rawValue + (forward ? 1 : -1)
        guard let day = Weekday(rawValue: next) else { return }
        activeDay = day
    }

    func selectTab(_ weekday: Weekday) {
        activeDay = weekday
    }

    /// Count of completed checkboxes for a day, shown on its tab.
    func completedTaskCount(_ weekday: Weekday) -> Int {
        MarkdownTasks.counts(in: currentWeek?.day(weekday).markdown ?? "").done
    }

    // MARK: - Template editing

    func saveTemplate(_ template: Template) {
        data.template = template
        scheduleSave()
    }

    // MARK: - Export

    /// Assemble every saved week into one readable Markdown document.
    func exportMarkdown() -> String {
        var out = ""
        for week in weeksSorted {
            out += "# \(WeekMath.weekLabel(for: week.weekStart))\n\n"
            appendSection(&out, title: "Big Three", body: week.bigThreeMarkdown)
            appendSection(&out, title: "This Week", body: week.weekTasksMarkdown)
            for weekday in Weekday.allCases {
                appendSection(&out, title: weekday.fullName, body: week.day(weekday).markdown)
            }
        }
        return out
    }

    private func appendSection(_ out: inout String, title: String, body: String) {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        out += "## \(title)\n\n\(trimmed)\n\n"
    }

    /// Present a save panel and write the Markdown export to the chosen file.
    /// Snapshots the Markdown first and dismisses the Settings sheet, then runs
    /// the save panel non-blocking so it does not nest inside the sheet's modal
    /// session.
    func exportMarkdownToFile() {
        let markdown = exportMarkdown()
        activeSheet = nil
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "markdone-export.md"
        panel.allowedContentTypes = [.init(filenameExtension: "md") ?? .plainText]
        panel.canCreateDirectories = true
        panel.title = "Export Tasks to Markdown"
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try markdown.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                self?.logger.error("Failed to export Markdown: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Saving

    func flushPendingSave() {
        saveWorkItem?.cancel()
        saveWorkItem = nil
        writeToDisk()
    }

    private func scheduleSave() {
        saveState = .saving
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.writeToDisk()
        }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func writeToDisk() {
        do {
            try FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let bytes = try encoder.encode(data)
            try bytes.write(to: dataURL, options: .atomic)
            saveState = .saved
        } catch {
            saveState = .failed
            logger.error("Failed to save data: \(error.localizedDescription, privacy: .public)")
        }
    }
}

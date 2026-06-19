import SwiftUI
import AppKit
import os

/// The three keyboard-focus regions, in Tab-cycle order.
enum Region: Int {
    case dayTabs
    case thisWeek
    case tasks
}

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

/// Where a given item lives inside the current week. Returned by `locate(_:)`
/// so every operation can switch on the item's kind.
enum ItemLocation: Equatable {
    case bigThree(Int)
    case weekTask(Int)
    case dayTask(Weekday, Int)
    case habit(Weekday, Int)
}

enum SaveState {
    case saved
    case saving
}

/// The single source of truth: all saved weeks, the template, the current
/// selection, the keyboard-focus state, and local persistence.
@MainActor
final class WeekStore: ObservableObject {
    @Published private(set) var data = TaskdownData()
    @Published var selectedWeekID: UUID = UUID()
    @Published var activeDay: Weekday = .monday

    // Keyboard focus and selection.
    @Published var region: Region = .thisWeek
    @Published var selectedID: UUID?
    @Published var editingID: UUID?
    /// The in-progress edit text for the row being renamed.
    @Published var draftText: String = ""

    @Published var activeSheet: ActiveSheet?
    @Published private(set) var saveState: SaveState = .saved

    /// Tracks a freshly created task so an empty title on commit removes it.
    private var newItemID: UUID?

    /// Remembers the last selected row in each column so moving away and back
    /// (to the other column or up to the day tabs) restores the position.
    private var lastSelection: [Region: UUID] = [:]
    /// The column to drop back into when leaving the day tabs with Down.
    private var returnColumn: Region = .tasks
    /// The habit last focused, so returning to the habits row restores it.
    private var lastHabitID: UUID?

    /// Closure the AppDelegate sets so Escape can close the popover.
    var onRequestClose: (() -> Void)?

    private let logger = Logger(subsystem: "com.taskdown.app", category: "store")
    private var saveWorkItem: DispatchWorkItem?

    // MARK: - Persistence paths

    private var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Taskdown", isDirectory: true)
    }

    private var dataURL: URL {
        supportDirectory.appendingPathComponent("data.json")
    }

    // MARK: - Lifecycle

    init() {
        load()
        ensureSomeWeek()
        selectDefaultFocus()
    }

    private func load() {
        let url = dataURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let bytes = try Data(contentsOf: url)
            data = try JSONDecoder().decode(TaskdownData.self, from: bytes)
        } catch {
            logger.error("Failed to load data: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Make sure at least the current calendar week exists, and select a week.
    private func ensureSomeWeek() {
        let thisMonday = WeekMath.mondayOfWeek(containing: Date())
        if data.weeks.isEmpty {
            data.weeks.append(seededWeek(monday: thisMonday))
            scheduleSave()
        }
        // Prefer selecting the current calendar week if present, else the latest.
        let sorted = weeksSorted
        if let current = sorted.first(where: { $0.weekStart == thisMonday }) {
            selectedWeekID = current.id
        } else if let latest = sorted.last {
            selectedWeekID = latest.id
        }
        // Default the active day to today when viewing the current week.
        let todayWeekday = weekdayOfToday()
        if currentWeek?.weekStart == thisMonday {
            activeDay = todayWeekday
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
        selectDefaultFocus()
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
        // Avoid duplicating a Monday that already exists.
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

    /// Build a new week from the template: empty Big Three, This Week tasks
    /// and each day's habits and tasks seeded from the template names.
    private func seededWeek(monday: Date) -> Week {
        var week = Week(weekStart: monday)
        week.weekTasks = data.template.weekTasks.map { TaskItem(title: $0) }
        week.days = Weekday.allCases.map { weekday in
            DayPlan(
                weekday: weekday,
                habits: data.template.habits.map { TaskItem(title: $0) },
                tasks: data.template.tasks(for: weekday).map { TaskItem(title: $0) }
            )
        }
        return week
    }

    // MARK: - Mutating the current week

    private func withCurrentWeek(_ mutate: (inout Week) -> Void) {
        guard let i = data.weeks.firstIndex(where: { $0.id == selectedWeekID }) else { return }
        mutate(&data.weeks[i])
        scheduleSave()
    }

    /// Find where an item id lives in the current week.
    func locate(_ id: UUID) -> ItemLocation? {
        guard let week = currentWeek else { return nil }
        if let i = week.bigThree.firstIndex(where: { $0.id == id }) { return .bigThree(i) }
        if let i = week.weekTasks.firstIndex(where: { $0.id == id }) { return .weekTask(i) }
        for day in week.days {
            if let i = day.habits.firstIndex(where: { $0.id == id }) { return .habit(day.weekday, i) }
            if let i = day.tasks.firstIndex(where: { $0.id == id }) { return .dayTask(day.weekday, i) }
        }
        return nil
    }

    func toggleDone(_ id: UUID) {
        guard let location = locate(id) else { return }
        withCurrentWeek { week in
            switch location {
            case .bigThree(let i):
                guard !week.bigThree[i].title.isEmpty else { return }
                week.bigThree[i].done.toggle()
            case .weekTask(let i):
                week.weekTasks[i].done.toggle()
            case .dayTask(let day, let i):
                if let d = week.days.firstIndex(where: { $0.weekday == day }) {
                    week.days[d].tasks[i].done.toggle()
                }
            case .habit(let day, let i):
                if let d = week.days.firstIndex(where: { $0.weekday == day }) {
                    week.days[d].habits[i].done.toggle()
                }
            }
        }
    }

    func setTitle(_ id: UUID, _ title: String) {
        guard let location = locate(id) else { return }
        withCurrentWeek { week in
            switch location {
            case .bigThree(let i): week.bigThree[i].title = title
            case .weekTask(let i): week.weekTasks[i].title = title
            case .dayTask(let day, let i):
                if let d = week.days.firstIndex(where: { $0.weekday == day }) {
                    week.days[d].tasks[i].title = title
                }
            case .habit(let day, let i):
                if let d = week.days.firstIndex(where: { $0.weekday == day }) {
                    week.days[d].habits[i].title = title
                }
            }
        }
    }

    // MARK: - Adding tasks

    /// Add a new This Week (undated) task and begin editing it.
    func addWeekTask() {
        let item = TaskItem(title: "")
        withCurrentWeek { $0.weekTasks.append(item) }
        region = .thisWeek
        selectedID = item.id
        beginEditing(item.id, isNew: true)
    }

    /// Add a new task to the active day and begin editing it.
    func addDayTask() {
        let item = TaskItem(title: "")
        withCurrentWeek { week in
            if let d = week.days.firstIndex(where: { $0.weekday == activeDay }) {
                week.days[d].tasks.append(item)
            }
        }
        region = .tasks
        selectedID = item.id
        beginEditing(item.id, isNew: true)
    }

    // MARK: - Editing lifecycle

    func beginEditing(_ id: UUID, isNew: Bool = false) {
        // Habits are template-driven; their titles are not editable here.
        if case .habit = locate(id) { return }
        selectedID = id
        editingID = id
        newItemID = isNew ? id : nil
        draftText = currentTitle(of: id) ?? ""
    }

    private func currentTitle(of id: UUID) -> String? {
        guard let location = locate(id), let week = currentWeek else { return nil }
        switch location {
        case .bigThree(let i): return week.bigThree[i].title
        case .weekTask(let i): return week.weekTasks[i].title
        case .dayTask(let day, let i): return week.day(day).tasks[i].title
        case .habit(let day, let i): return week.day(day).habits[i].title
        }
    }

    /// Begin renaming the currently selected item, if it is renameable.
    func beginEditingSelected() {
        guard let id = selectedID else { return }
        beginEditing(id, isNew: false)
    }

    /// Accept the in-progress edit (from the field's draft text). A brand-new
    /// task left empty is discarded.
    func commitEditing() {
        guard let id = editingID else { return }
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        setTitle(id, trimmed)
        if id == newItemID, trimmed.isEmpty {
            delete(id)
        }
        editingID = nil
        newItemID = nil
    }

    func cancelEditing() {
        guard let id = editingID else { return }
        if id == newItemID {
            delete(id)
        }
        editingID = nil
        newItemID = nil
    }

    // MARK: - Deleting

    /// Delete the selected item. Big Three slots are cleared rather than
    /// removed; habits are template-driven and are not deleted here.
    func deleteSelected() {
        guard let id = selectedID, let location = locate(id) else { return }
        switch location {
        case .bigThree(let i):
            withCurrentWeek { $0.bigThree[i] = TaskItem(title: "") }
        case .habit:
            return
        case .weekTask, .dayTask:
            delete(id)
        }
    }

    private func delete(_ id: UUID) {
        guard let location = locate(id) else { return }
        // Choose a neighbor to select after removal.
        let order = orderedIDs(for: region)
        let removingIndex = order.firstIndex(of: id)

        withCurrentWeek { week in
            switch location {
            case .weekTask(let i): week.weekTasks.remove(at: i)
            case .dayTask(let day, let i):
                if let d = week.days.firstIndex(where: { $0.weekday == day }) {
                    week.days[d].tasks.remove(at: i)
                }
            case .bigThree, .habit:
                break
            }
        }

        // Reselect a sensible neighbor.
        let newOrder = orderedIDs(for: region)
        if newOrder.isEmpty {
            selectedID = nil
        } else if let idx = removingIndex {
            selectedID = newOrder[min(idx, newOrder.count - 1)]
        } else {
            selectedID = newOrder.first
        }
    }

    // MARK: - Moving along the chain (This Week <-> days)

    /// Move the selected task one step along the chain
    /// `This Week -> Mon -> Tue -> ... -> Sun`. The active day follows the
    /// task so it can be pushed further. Big Three slots and habits do not move.
    func moveSelectedAlongChain(forward: Bool) {
        guard let id = selectedID, let location = locate(id) else { return }

        // Current position: 0 = This Week, 1..7 = Monday..Sunday.
        let position: Int
        let item: TaskItem
        switch location {
        case .weekTask(let i):
            position = 0
            item = currentWeek!.weekTasks[i]
        case .dayTask(let day, let i):
            position = day.rawValue + 1
            item = currentWeek!.day(day).tasks[i]
        case .bigThree, .habit:
            return
        }

        let newPosition = forward ? min(position + 1, 7) : max(position - 1, 0)
        if newPosition == position { return }

        // Remove from old container.
        withCurrentWeek { week in
            switch location {
            case .weekTask(let i): week.weekTasks.remove(at: i)
            case .dayTask(let day, let i):
                if let d = week.days.firstIndex(where: { $0.weekday == day }) {
                    week.days[d].tasks.remove(at: i)
                }
            default: break
            }
            // Insert into new container.
            if newPosition == 0 {
                week.weekTasks.append(item)
            } else {
                let weekday = Weekday(rawValue: newPosition - 1) ?? .monday
                if let d = week.days.firstIndex(where: { $0.weekday == weekday }) {
                    week.days[d].tasks.append(item)
                }
            }
        }

        // Follow the task to its new home.
        if newPosition == 0 {
            region = .thisWeek
        } else {
            activeDay = Weekday(rawValue: newPosition - 1) ?? .monday
            region = .tasks
        }
        selectedID = item.id
    }

    /// Move a specific item to an absolute chain position (0 = This Week,
    /// 1...7 = Monday...Sunday). Used by the row "Move to" menu.
    func moveItem(_ id: UUID, toPosition pos: Int) {
        guard let location = locate(id) else { return }
        let item: TaskItem
        switch location {
        case .weekTask(let i): item = currentWeek!.weekTasks[i]
        case .dayTask(let day, let i): item = currentWeek!.day(day).tasks[i]
        case .bigThree, .habit: return
        }
        let clamped = max(0, min(pos, 7))
        withCurrentWeek { week in
            switch location {
            case .weekTask(let i): week.weekTasks.remove(at: i)
            case .dayTask(let day, let i):
                if let d = week.days.firstIndex(where: { $0.weekday == day }) {
                    week.days[d].tasks.remove(at: i)
                }
            default: break
            }
            if clamped == 0 {
                week.weekTasks.append(item)
            } else {
                let weekday = Weekday(rawValue: clamped - 1) ?? .monday
                if let d = week.days.firstIndex(where: { $0.weekday == weekday }) {
                    week.days[d].tasks.append(item)
                }
            }
        }
        if clamped == 0 {
            region = .thisWeek
        } else {
            activeDay = Weekday(rawValue: clamped - 1) ?? .monday
            region = .tasks
        }
        selectedID = item.id
    }

    // MARK: - Reordering within a list (Shift+Up/Down)

    func reorderSelected(up: Bool) {
        guard let id = selectedID, let location = locate(id) else { return }
        withCurrentWeek { week in
            switch location {
            case .weekTask(let i):
                let j = up ? i - 1 : i + 1
                guard week.weekTasks.indices.contains(j) else { return }
                week.weekTasks.swapAt(i, j)
            case .dayTask(let day, let i):
                guard let d = week.days.firstIndex(where: { $0.weekday == day }) else { return }
                let j = up ? i - 1 : i + 1
                guard week.days[d].tasks.indices.contains(j) else { return }
                week.days[d].tasks.swapAt(i, j)
            case .bigThree, .habit:
                return
            }
        }
    }

    // MARK: - Focus and selection helpers

    /// The ordered list of focusable item ids for a region in the current week.
    func orderedIDs(for region: Region) -> [UUID] {
        guard let week = currentWeek else { return [] }
        switch region {
        case .dayTabs:
            return []
        case .thisWeek:
            return week.bigThree.map { $0.id } + week.weekTasks.map { $0.id }
        case .tasks:
            let day = week.day(activeDay)
            return day.habits.map { $0.id } + day.tasks.map { $0.id }
        }
    }

    private func selectDefaultFocus() {
        region = .thisWeek
        selectedID = orderedIDs(for: .thisWeek).first
    }

    /// Habit and task ids for the active day, kept separate because the habits
    /// form one horizontal row at the top of the Tasks column.
    var activeDayHabitIDs: [UUID] { currentWeek?.day(activeDay).habits.map { $0.id } ?? [] }
    var activeDayTaskIDs: [UUID] { currentWeek?.day(activeDay).tasks.map { $0.id } ?? [] }

    /// Up/Down. Within a column, move the selection one row. Pressing Up at the
    /// top of a column jumps to the day tabs; pressing Down on the day tabs
    /// drops back into the column you came from. In the Tasks column the whole
    /// habits row is a single vertical stop (move between habits with Left/Right).
    func navigateVertical(up: Bool) {
        switch region {
        case .dayTabs:
            if !up { returnFromDayTabs() }
        case .thisWeek:
            stepWithinList(up: up, order: orderedIDs(for: .thisWeek))
        case .tasks:
            navigateTasksVertical(up: up)
        }
    }

    private func stepWithinList(up: Bool, order: [UUID]) {
        guard !order.isEmpty else {
            if up { goToDayTabs(from: region) }
            return
        }
        guard let current = selectedID, let idx = order.firstIndex(of: current) else {
            selectedID = order.first
            return
        }
        let next = up ? idx - 1 : idx + 1
        if order.indices.contains(next) {
            selectedID = order[next]
        } else if up {
            goToDayTabs(from: region)
        }
    }

    private func navigateTasksVertical(up: Bool) {
        let habits = activeDayHabitIDs
        let tasks = activeDayTaskIDs
        let onHabitRow = selectedID.map { habits.contains($0) } ?? false

        if onHabitRow {
            if up {
                goToDayTabs(from: .tasks)
            } else if let firstTask = tasks.first {
                selectedID = firstTask
            }
            return
        }

        // Otherwise the focus is on a task row (or nothing yet).
        guard let current = selectedID, let idx = tasks.firstIndex(of: current) else {
            if let firstTask = tasks.first {
                selectedID = firstTask
            } else if up {
                enterHabitRowOrTabs(habits)
            }
            return
        }
        let next = up ? idx - 1 : idx + 1
        if tasks.indices.contains(next) {
            selectedID = tasks[next]
        } else if up {
            // Above the first task: the habits row, or the day tabs if none.
            enterHabitRowOrTabs(habits)
        }
        // Below the last task: stay put.
    }

    private func enterHabitRowOrTabs(_ habits: [UUID]) {
        if habits.isEmpty {
            goToDayTabs(from: .tasks)
        } else {
            enterHabitRow(habits)
        }
    }

    private func enterHabitRow(_ habits: [UUID]) {
        let target = (lastHabitID.flatMap { habits.contains($0) ? $0 : nil }) ?? habits.first
        selectedID = target
        lastHabitID = target
    }

    /// Left/Right. In the This Week column, Right moves to Tasks. In the Tasks
    /// column on a task row, Left moves back to This Week. On the habits row,
    /// Left/Right move between the habit chips, and Left past the first habit
    /// exits to the This Week column. On the day tabs, switch the active day.
    func navigateHorizontal(right: Bool) {
        switch region {
        case .dayTabs:
            switchDay(forward: right)
        case .thisWeek:
            if right { focusColumn(.tasks) }
        case .tasks:
            navigateTasksHorizontal(right: right)
        }
    }

    private func navigateTasksHorizontal(right: Bool) {
        let habits = activeDayHabitIDs
        if let current = selectedID, let idx = habits.firstIndex(of: current) {
            // On the habits row: move between chips, exit left past the first.
            let next = right ? idx + 1 : idx - 1
            if habits.indices.contains(next) {
                selectedID = habits[next]
                lastHabitID = habits[next]
            } else if !right {
                focusColumn(.thisWeek)
            }
            // Right past the last habit: nothing (Tasks is the rightmost column).
        } else {
            // On a task row: Left returns to This Week.
            if !right { focusColumn(.thisWeek) }
        }
    }

    private func focusColumn(_ target: Region) {
        if region == .thisWeek || region == .tasks {
            lastSelection[region] = selectedID
        }
        region = target
        restoreSelection(in: target)
    }

    private func goToDayTabs(from column: Region) {
        lastSelection[column] = selectedID
        returnColumn = column
        region = .dayTabs
    }

    private func returnFromDayTabs() {
        region = returnColumn
        restoreSelection(in: returnColumn)
    }

    /// Select the remembered row for a column, or its first row if that row no
    /// longer exists (for example after switching days).
    private func restoreSelection(in column: Region) {
        let order = orderedIDs(for: column)
        if let saved = lastSelection[column], order.contains(saved) {
            selectedID = saved
        } else {
            selectedID = order.first
        }
    }

    func cycleRegion(forward: Bool) {
        let all: [Region] = [.dayTabs, .thisWeek, .tasks]
        guard let idx = all.firstIndex(of: region) else { return }
        let nextIdx = (idx + (forward ? 1 : -1) + all.count) % all.count
        region = all[nextIdx]
        if region == .dayTabs {
            selectedID = nil
        } else {
            let order = orderedIDs(for: region)
            if let current = selectedID, order.contains(current) {
                // keep selection
            } else {
                selectedID = order.first
            }
        }
    }

    func switchDay(forward: Bool) {
        let next = activeDay.rawValue + (forward ? 1 : -1)
        guard let day = Weekday(rawValue: next) else { return }
        activeDay = day
        if region == .tasks {
            selectedID = orderedIDs(for: .tasks).first
        }
    }

    func selectTab(_ weekday: Weekday) {
        activeDay = weekday
        if region == .tasks {
            selectedID = orderedIDs(for: .tasks).first
        }
    }

    /// Count of completed tasks (not habits) for a day tab badge.
    func completedTaskCount(_ weekday: Weekday) -> Int {
        guard let week = currentWeek else { return 0 }
        return week.day(weekday).tasks.filter { $0.done }.count
    }

    // MARK: - Template editing

    func saveTemplate(_ template: Template) {
        data.template = template
        scheduleSave()
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
            logger.error("Failed to save data: \(error.localizedDescription, privacy: .public)")
        }
    }
}

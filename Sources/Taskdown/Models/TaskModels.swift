import Foundation

/// The seven weekdays, Monday first. Raw value is the storage/order index.
enum Weekday: Int, Codable, CaseIterable, Identifiable, Hashable {
    case monday = 0, tuesday, wednesday, thursday, friday, saturday, sunday

    var id: Int { rawValue }

    /// Short label shown on a day tab, for example "Mon".
    var shortLabel: String {
        switch self {
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        case .sunday: return "Sun"
        }
    }
}

/// A single task or habit row. The same type backs Big Three slots, This Week
/// tasks, per-day tasks, and per-day habits. `done` is the only mutable state
/// beyond the title.
struct TaskItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var done: Bool = false

    init(id: UUID = UUID(), title: String, done: Bool = false) {
        self.id = id
        self.title = title
        self.done = done
    }
}

/// One day inside a week. Holds that day's own habit checkboxes (seeded from
/// the template's habit names) and that day's scheduled tasks.
struct DayPlan: Codable, Hashable {
    var weekday: Weekday
    var habits: [TaskItem] = []
    var tasks: [TaskItem] = []
}

/// One saved week. `weekStart` is always the Monday of that week.
///
/// `bigThree` is per-week and starts empty (the template never seeds it).
/// `weekTasks` are undated tasks for the week — created when there is no
/// specific day to do them on, and later pushed into a day. Each `DayPlan`
/// carries its own habits and tasks.
struct Week: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var weekStart: Date
    var bigThree: [TaskItem] = [
        TaskItem(title: ""),
        TaskItem(title: ""),
        TaskItem(title: "")
    ]
    var weekTasks: [TaskItem] = []
    var days: [DayPlan] = Weekday.allCases.map { DayPlan(weekday: $0) }

    func day(_ weekday: Weekday) -> DayPlan {
        days.first { $0.weekday == weekday } ?? DayPlan(weekday: weekday)
    }

    /// Completed and total counts across every task-like item in the week:
    /// Big Three (non-empty slots only), This Week tasks, and every day's
    /// tasks and habits. Used by the top bar's `done/total` badge.
    var completion: (done: Int, total: Int) {
        var done = 0
        var total = 0
        for item in bigThree where !item.title.isEmpty {
            total += 1
            if item.done { done += 1 }
        }
        for item in weekTasks {
            total += 1
            if item.done { done += 1 }
        }
        for day in days {
            for item in day.tasks {
                total += 1
                if item.done { done += 1 }
            }
            for item in day.habits {
                total += 1
                if item.done { done += 1 }
            }
        }
        return (done, total)
    }
}

/// The weekly template. Edits apply to new weeks only. It stores names rather
/// than live `TaskItem`s, because a template entry produces a fresh, unchecked
/// item in each new week.
struct Template: Codable, Hashable {
    /// Daily habit names. Every day of a new week gets one unchecked habit per
    /// name.
    var habits: [String] = []
    /// This Week (undated) recurring task names.
    var weekTasks: [String] = []
    /// Recurring task names per day.
    var dayTasks: [Int: [String]] = [:]

    func tasks(for weekday: Weekday) -> [String] {
        dayTasks[weekday.rawValue] ?? []
    }
}

/// Top-level persisted document: every saved week plus the template.
struct TaskdownData: Codable {
    var weeks: [Week] = []
    var template: Template = Template()
}

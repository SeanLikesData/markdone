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

    /// Full name, used in the Markdown export and as a day heading.
    var fullName: String {
        switch self {
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        case .sunday: return "Sunday"
        }
    }
}

/// One day inside a week. Its tasks and notes live in a single Markdown block
/// that the user edits directly. Checkboxes (`[ ]` / `[x]`) inside the block are
/// the tasks; everything else is free-form notes and structure.
struct DayPlan: Codable, Hashable {
    var weekday: Weekday
    var markdown: String = ""
}

/// One saved week. `weekStart` is always the Monday of that week. Every region
/// is a Markdown block: the per-week Big Three priorities, the undated This Week
/// tasks, and one block per day.
struct Week: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var weekStart: Date
    var bigThreeMarkdown: String = ""
    var weekTasksMarkdown: String = ""
    var days: [DayPlan] = Weekday.allCases.map { DayPlan(weekday: $0) }

    func day(_ weekday: Weekday) -> DayPlan {
        days.first { $0.weekday == weekday } ?? DayPlan(weekday: weekday)
    }

    /// Completed and total checkbox counts across every block in the week. Used
    /// by the week pill and the Weeks panel.
    var completion: (done: Int, total: Int) {
        var done = 0
        var total = 0
        for markdown in [bigThreeMarkdown, weekTasksMarkdown] + days.map(\.markdown) {
            let counts = MarkdownTasks.counts(in: markdown)
            done += counts.done
            total += counts.total
        }
        return (done, total)
    }
}

/// The weekly template. Each field is a Markdown block that seeds the matching
/// block of every new week. Edits apply to new weeks only.
struct Template: Codable, Hashable {
    var bigThreeMarkdown: String = ""
    var weekTasksMarkdown: String = ""
    /// Per-day seed blocks, keyed by `Weekday.rawValue`.
    var dayMarkdown: [Int: String] = [:]

    func markdown(for weekday: Weekday) -> String {
        dayMarkdown[weekday.rawValue] ?? ""
    }
}

/// Top-level persisted document: every saved week plus the template.
struct TaskdownData: Codable {
    var weeks: [Week] = []
    var template: Template = Template()
}

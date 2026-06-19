import Foundation

/// Week math, fixed to a Monday-first week regardless of the user's locale
/// first-weekday setting, so day tabs always read Monday through Sunday.
enum WeekMath {
    /// A calendar whose first weekday is Monday.
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // 1 = Sunday, 2 = Monday
        return calendar
    }

    /// The Monday at or before the given date, with the time set to midnight.
    static func mondayOfWeek(containing date: Date) -> Date {
        let calendar = calendar
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay) // 1=Sun...7=Sat
        // Days since the most recent Monday.
        let daysSinceMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysSinceMonday, to: startOfDay) ?? startOfDay
    }

    /// The Monday one week after the given Monday.
    static func nextMonday(after monday: Date) -> Date {
        calendar.date(byAdding: .day, value: 7, to: monday) ?? monday
    }

    /// "Week of Jun 15, 2026" style label for a Monday date.
    static func weekLabel(for monday: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "MMM d, yyyy"
        return "Week of \(formatter.string(from: monday))"
    }
}

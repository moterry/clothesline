import Foundation

/// A calendar day (no time of day).
struct Day: Hashable, Comparable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(_ date: Date, calendar: Calendar) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year!, month: c.month!, day: c.day!)
    }

    /// Midnight at the start of this day in `calendar`'s time zone.
    func startDate(calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// Whole days from `self` to `other` (positive when `other` is later).
    func days(until other: Day, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: startDate(calendar: calendar), to: other.startDate(calendar: calendar)).day!
    }

    static func < (a: Day, b: Day) -> Bool {
        (a.year, a.month, a.day) < (b.year, b.month, b.day)
    }
}

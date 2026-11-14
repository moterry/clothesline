import Foundation

/// Fixed calendar for all tests: Gregorian, UTC+8.
let testCalendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
    return c
}()

/// Parses "yyyy-MM-dd HH:mm" in `testCalendar`'s time zone.
func at(_ s: String) -> Date {
    let f = DateFormatter()
    f.calendar = testCalendar
    f.timeZone = testCalendar.timeZone
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd HH:mm"
    return f.date(from: s)!
}

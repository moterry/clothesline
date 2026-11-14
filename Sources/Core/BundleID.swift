import Foundation

/// Identity of one bundle in the river: the day it belongs to and its ordinal within that day.
/// On disk it is a folder named like `2026-11-14 · II`.
struct BundleID: Hashable, Comparable, Sendable {
    let day: Day
    let ordinal: Int

    static let separator = " \u{00B7} "

    init(day: Day, ordinal: Int) {
        self.day = day
        self.ordinal = ordinal
    }

    var folderName: String {
        String(format: "%04d-%02d-%02d", day.year, day.month, day.day) + Self.separator + Roman.numeral(ordinal)
    }

    init?(folderName: String) {
        let parts = folderName.components(separatedBy: Self.separator)
        guard parts.count == 2 else { return nil }
        let dateParts = parts[0].split(separator: "-")
        guard dateParts.count == 3,
              let y = Int(dateParts[0]), let m = Int(dateParts[1]), let d = Int(dateParts[2]),
              (1...3999).contains(y), (1...12).contains(m), (1...31).contains(d),
              let ordinal = (1...3999).first(where: { Roman.numeral($0) == parts[1] })
        else { return nil }
        self.init(day: Day(year: y, month: m, day: d), ordinal: ordinal)
    }

    /// Newest first: later day first, then higher ordinal first.
    static func < (a: BundleID, b: BundleID) -> Bool {
        if a.day != b.day { return a.day > b.day }
        return a.ordinal > b.ordinal
    }
}

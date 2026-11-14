import Foundation
import Testing

@Test func labels() {
    #expect(Labels.today(Day(year: 2026, month: 11, day: 14)) == "HODIE · XIV · XI")
    let one = BundleID(day: Day(year: 2026, month: 11, day: 13), ordinal: 1)
    #expect(Labels.bundle(one, dayHasSeveral: false, currentYear: 2026) == "XIII · XI")
    let two = BundleID(day: Day(year: 2026, month: 11, day: 14), ordinal: 2)
    #expect(Labels.bundle(two, dayHasSeveral: true, currentYear: 2026) == "XIV · XI · II")
    let old = BundleID(day: Day(year: 2025, month: 11, day: 14), ordinal: 1)
    #expect(Labels.bundle(old, dayHasSeveral: false, currentYear: 2026) == "XIV · XI · MMXXV")
    let oldTwo = BundleID(day: Day(year: 2025, month: 11, day: 14), ordinal: 2)
    #expect(Labels.bundle(oldTwo, dayHasSeveral: true, currentYear: 2026) == "XIV · XI · MMXXV · II")
}

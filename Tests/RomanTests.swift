import Foundation
import Testing

@Test func romanBasics() {
    #expect(Roman.numeral(1) == "I")
    #expect(Roman.numeral(4) == "IV")
    #expect(Roman.numeral(9) == "IX")
    #expect(Roman.numeral(14) == "XIV")
    #expect(Roman.numeral(28) == "XXVIII")
    #expect(Roman.numeral(2025) == "MMXXV")
}

@Test func dayFromDateUsesCalendar() {
    #expect(Day(at("2026-11-14 23:59"), calendar: testCalendar) == Day(year: 2026, month: 11, day: 14))
}

@Test func dayDistance() {
    #expect(Day(year: 2026, month: 10, day: 15).days(until: Day(year: 2026, month: 11, day: 14), calendar: testCalendar) == 30)
}

@Test func folderNameRoundTrip() {
    let id = BundleID(day: Day(year: 2026, month: 11, day: 14), ordinal: 2)
    #expect(id.folderName == "2026-11-14 · II")
    #expect(BundleID(folderName: "2026-11-14 · II") == id)
    #expect(BundleID(folderName: "2026-11-14") == nil)
    #expect(BundleID(folderName: "notes") == nil)
}

@Test func bundleOrderNewestFirst() {
    let a = BundleID(day: Day(year: 2026, month: 11, day: 14), ordinal: 1)
    let b = BundleID(day: Day(year: 2026, month: 11, day: 14), ordinal: 2)
    let c = BundleID(day: Day(year: 2026, month: 11, day: 13), ordinal: 1)
    #expect([c, a, b].sorted() == [b, a, c])
}

@Test func folderNameRejectsYearsRomanCannotShow() {
    // A Finder typo must never reach Roman.numeral's precondition (crash on every launch).
    #expect(BundleID(folderName: "20266-11-14 · I") == nil)
    #expect(BundleID(folderName: "0000-11-14 · I") == nil)
}

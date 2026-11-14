import Foundation

/// The inscriptions shown on the line and in the river.
enum Labels {
    /// "HODIE · XIV · XI"
    static func today(_ day: Day) -> String {
        ["HODIE", Roman.numeral(day.day), Roman.numeral(day.month)].joined(separator: BundleID.separator)
    }

    /// "XIII · XI", plus the year when it is not `currentYear`, plus the ordinal when the day has several bundles.
    static func bundle(_ id: BundleID, dayHasSeveral: Bool, currentYear: Int) -> String {
        var parts = [Roman.numeral(id.day.day), Roman.numeral(id.day.month)]
        if id.day.year != currentYear { parts.append(Roman.numeral(id.day.year)) }
        if dayHasSeveral { parts.append(Roman.numeral(id.ordinal)) }
        return parts.joined(separator: BundleID.separator)
    }
}

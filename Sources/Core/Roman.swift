import Foundation

/// Roman numerals, used for every date the app shows.
enum Roman {
    private static let table: [(Int, String)] = [
        (1000, "M"), (900, "CM"), (500, "D"), (400, "CD"),
        (100, "C"), (90, "XC"), (50, "L"), (40, "XL"),
        (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I"),
    ]

    /// Roman numeral for 1...3999.
    static func numeral(_ n: Int) -> String {
        precondition((1...3999).contains(n), "Roman numerals cover 1...3999")
        var rest = n
        var out = ""
        for (value, symbol) in table {
            while rest >= value {
                out += symbol
                rest -= value
            }
        }
        return out
    }
}

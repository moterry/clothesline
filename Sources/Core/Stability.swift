import Foundation

/// Decides when files have finished being written.
enum Stability {
    static func isSettled(before: [URL: Int], after: [URL: Int]) -> Bool {
        before == after
    }
}

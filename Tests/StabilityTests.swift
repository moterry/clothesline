import Foundation
import Testing

private let a = URL(fileURLWithPath: "/r/a.png")

@Test func unchangedSizesAreSettledEvenWhenEmpty() {
    // A stray 0-byte image must not stall catching forever.
    #expect(Stability.isSettled(before: [a: 0], after: [a: 0]))
    #expect(Stability.isSettled(before: [a: 120], after: [a: 120]))
}

@Test func growingOrNewFilesAreNotSettled() {
    #expect(!Stability.isSettled(before: [a: 10], after: [a: 20]))
    #expect(!Stability.isSettled(before: [:], after: [a: 20]))
}

import Foundation
import Testing

final class FakeShell: DefaultsShell {
    var location: String?
    var deletes = 0
    init(_ location: String?) { self.location = location }
    func readLocation() -> String? { location }
    func writeLocation(_ path: String) { location = path }
    func deleteLocation() { location = nil; deletes += 1 }
}

private func memory() -> UserDefaults { UserDefaults(suiteName: "clothesline-tests-\(UUID().uuidString)")! }
private let lib = URL(fileURLWithPath: "/Users/x/Pictures/Clothesline", isDirectory: true)

@Test func adoptRemembersCustomOriginal() {
    let shell = FakeShell("/Users/x/Shots")
    let loc = ScreenshotLocation(shell: shell, memory: memory())
    loc.adopt(lib)
    #expect(shell.location == lib.path)
    loc.restore()
    #expect(shell.location == "/Users/x/Shots")
}

@Test func adoptRemembersUnset() {
    let shell = FakeShell(nil)
    let loc = ScreenshotLocation(shell: shell, memory: memory())
    loc.adopt(lib)
    loc.restore()
    #expect(shell.location == nil)
    #expect(shell.deletes == 1)
}

@Test func adoptTwiceKeepsFirstOriginal() {
    let shell = FakeShell("/A")
    let mem = memory()
    ScreenshotLocation(shell: shell, memory: mem).adopt(lib)
    let again = ScreenshotLocation(shell: shell, memory: mem)
    again.adopt(lib)
    again.restore()
    #expect(shell.location == "/A")
}

@Test func isAdoptedReflectsShell() {
    let shell = FakeShell("/A")
    let loc = ScreenshotLocation(shell: shell, memory: memory())
    #expect(!loc.isAdopted(lib))
    loc.adopt(lib)
    #expect(loc.isAdopted(lib))
    loc.restore()
    #expect(!loc.isAdopted(lib))
}

@Test func restoreWithoutAdoptDoesNothing() {
    let shell = FakeShell("/A")
    ScreenshotLocation(shell: shell, memory: memory()).restore()
    #expect(shell.location == "/A")
    #expect(shell.deletes == 0)
}

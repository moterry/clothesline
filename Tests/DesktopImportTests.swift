import Foundation
import Testing

private func tempDesktop() -> URL {
    let d = FileManager.default.temporaryDirectory.appending(path: "clothesline-tests/desk-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
    return d
}

@Test func findMatchesPrefixesOnly() {
    let desk = tempDesktop()
    for n in ["截屏 1.png", "Screenshot 2.png", "屏幕快照 3.png", "Screen Shot 4.png", "photo.png", "截屏 5.mov"] {
        makeImage(desk.appending(path: n), created: at("2026-11-14 10:00"))
    }
    let found = DesktopImport.find(in: desk).map(\.lastPathComponent).sorted()
    #expect(found == ["Screen Shot 4.png", "Screenshot 2.png", "截屏 1.png", "屏幕快照 3.png"].sorted())
}

@Test func importGroupsByDayAndSplitsByCapacity() throws {
    let desk = tempDesktop(); let lib = makeTempLibrary(); try lib.ensureExists()
    for i in 1...3 { makeImage(desk.appending(path: "截屏 12-\(i).png"), created: at("2026-11-12 1\(i):00")) }
    makeImage(desk.appending(path: "截屏 13.png"), created: at("2026-11-13 09:00"))
    let ids = try DesktopImport.importAll(DesktopImport.find(in: desk), paths: lib, capacity: 2, calendar: testCalendar)
    #expect(ids.sorted().map(\.folderName) == ["2026-11-13 · I", "2026-11-12 · II", "2026-11-12 · I"])
    #expect(names(in: desk).isEmpty)
    #expect(names(in: lib.river.appending(path: "2026-11-12 · I")) == ["截屏 12-1.png", "截屏 12-2.png"])
}

@Test func importContinuesExistingOrdinals() throws {
    let desk = tempDesktop(); let lib = makeTempLibrary(); try lib.ensureExists()
    makeImage(lib.river.appending(path: "2026-11-12 · I/old.png"), created: at("2026-11-12 08:00"))
    makeImage(desk.appending(path: "截屏 a.png"), created: at("2026-11-12 09:00"))
    let ids = try DesktopImport.importAll(DesktopImport.find(in: desk), paths: lib, capacity: 12, calendar: testCalendar)
    #expect(ids.map(\.folderName) == ["2026-11-12 · II"])
}

@Test func importDoesNotOverwrite() throws {
    let deskA = tempDesktop(), deskB = tempDesktop(); let lib = makeTempLibrary(); try lib.ensureExists()
    makeImage(deskA.appending(path: "截屏 1.png"), created: at("2026-11-12 09:00"))
    makeImage(deskB.appending(path: "截屏 1.png"), created: at("2026-11-12 09:01"))
    let files = DesktopImport.find(in: deskA) + DesktopImport.find(in: deskB)
    _ = try DesktopImport.importAll(files, paths: lib, capacity: 12, calendar: testCalendar)
    #expect(names(in: lib.river.appending(path: "2026-11-12 · I")) == ["截屏 1 (2).png", "截屏 1.png"])
}

import Foundation
import Testing

private func keeper(_ lib: LibraryPaths, capacity: Int = 12) -> RopeKeeper {
    RopeKeeper(paths: lib, calendar: testCalendar, capacity: capacity)
}

@Test func hangsInOrder() throws {
    let lib = makeTempLibrary(); try lib.ensureExists()
    makeImage(lib.root.appending(path: "b.png"), created: at("2026-11-14 10:05"))
    makeImage(lib.root.appending(path: "a.png"), created: at("2026-11-14 10:00"))
    let events = try keeper(lib).ingestPending()
    #expect(events == [.hung(lib.rope.appending(path: "a.png")), .hung(lib.rope.appending(path: "b.png"))])
    let s = try LibraryScanner.scan(lib)
    #expect(s.rope.map(\.url.lastPathComponent) == ["a.png", "b.png"])
    #expect(s.pending.isEmpty)
}

@Test func cutsWhenFullOnNextArrival() throws {
    let lib = makeTempLibrary(); try lib.ensureExists()
    for i in 1...4 { makeImage(lib.root.appending(path: "\(i).png"), created: at("2026-11-14 10:0\(i)")) }
    let events = try keeper(lib, capacity: 3).ingestPending()
    let first = BundleID(day: Day(year: 2026, month: 11, day: 14), ordinal: 1)
    #expect(events.count == 5)
    #expect(events[3] == .cut(first))
    let s = try LibraryScanner.scan(lib)
    #expect(s.rope.map(\.url.lastPathComponent) == ["4.png"])
    #expect(s.river.map(\.id) == [first])
    #expect(s.river[0].shots.count == 3)
}

@Test func secondCutSameDayGetsOrdinalII() throws {
    let lib = makeTempLibrary(); try lib.ensureExists()
    for i in 1...5 { makeImage(lib.root.appending(path: "\(i).png"), created: at("2026-11-14 10:0\(i)")) }
    _ = try keeper(lib, capacity: 2).ingestPending()
    let s = try LibraryScanner.scan(lib)
    #expect(s.river.map(\.id.folderName) == ["2026-11-14 · II", "2026-11-14 · I"])
    #expect(s.rope.count == 1)
}

@Test func ingestBurstKeepsAllInOrder() throws {
    let lib = makeTempLibrary(); try lib.ensureExists()
    for name in ["c.png", "a.png", "b.png"] { makeImage(lib.root.appending(path: name), created: at("2026-11-14 10:00")) }
    _ = try keeper(lib).ingestPending()
    #expect(try LibraryScanner.scan(lib).rope.map(\.url.lastPathComponent) == ["a.png", "b.png", "c.png"])
    #expect(names(in: lib.root).isEmpty)
}

@Test func backlogAcrossDaysGroupsByOwnDay() throws {
    let lib = makeTempLibrary(); try lib.ensureExists()
    makeImage(lib.root.appending(path: "d12a.png"), created: at("2026-11-12 09:00"))
    makeImage(lib.root.appending(path: "d12b.png"), created: at("2026-11-12 09:30"))
    for i in 1...3 { makeImage(lib.root.appending(path: "d13-\(i).png"), created: at("2026-11-13 1\(i):00")) }
    makeImage(lib.root.appending(path: "d14.png"), created: at("2026-11-14 08:00"))
    _ = try keeper(lib).ingestPending()
    let s = try LibraryScanner.scan(lib)
    #expect(s.river.map(\.id.folderName) == ["2026-11-13 · I", "2026-11-12 · I"])
    #expect(s.river.map(\.shots.count) == [3, 2])
    #expect(s.rope.map(\.url.lastPathComponent) == ["d14.png"])
}

@Test func cutIfStaleCutsYesterdaysRope() throws {
    let lib = makeTempLibrary(); try lib.ensureExists()
    makeImage(lib.rope.appending(path: "old.png"), created: at("2026-11-13 22:00"))
    let event = try keeper(lib).cutIfStale(now: at("2026-11-14 08:00"))
    #expect(event == .cut(BundleID(day: Day(year: 2026, month: 11, day: 13), ordinal: 1)))
    #expect(try LibraryScanner.scan(lib).rope.isEmpty)
}

@Test func cutIfStaleKeepsTodaysRope() throws {
    let lib = makeTempLibrary(); try lib.ensureExists()
    makeImage(lib.rope.appending(path: "now.png"), created: at("2026-11-14 07:00"))
    #expect(try keeper(lib).cutIfStale(now: at("2026-11-14 08:00")) == nil)
    #expect(try LibraryScanner.scan(lib).rope.count == 1)
}

@Test func cutOnEmptyRopeIsNil() throws {
    let lib = makeTempLibrary(); try lib.ensureExists()
    #expect(try keeper(lib).cut() == nil)
}

@Test func cutNeverOverwritesExistingBundleFiles() throws {
    let lib = makeTempLibrary(); try lib.ensureExists()
    // An existing "2026-11-14 · I" bundle: the next cut must take ordinal II, leaving it intact.
    makeImage(lib.river.appending(path: "2026-11-14 · I/a.png"), created: at("2026-11-14 08:00"))
    makeImage(lib.rope.appending(path: "a.png"), created: at("2026-11-14 09:00"))
    #expect(try keeper(lib).cut() == .cut(BundleID(day: Day(year: 2026, month: 11, day: 14), ordinal: 2)))
    #expect(names(in: lib.river.appending(path: "2026-11-14 · I")) == ["a.png"])
}

@Test func catchUpCutsBacklogFromEarlierDays() throws {
    // App was off overnight: last night's screenshots must not sit under today's HODIE.
    let lib = makeTempLibrary(); try lib.ensureExists()
    makeImage(lib.root.appending(path: "late.png"), created: at("2026-11-13 23:59"))
    _ = try keeper(lib).catchUp(now: at("2026-11-14 08:00"))
    let s = try LibraryScanner.scan(lib)
    #expect(s.rope.isEmpty)
    #expect(s.river.map(\.id.folderName) == ["2026-11-13 · I"])
}

@Test func catchUpKeepsTodaysScreenshotsOnTheLine() throws {
    let lib = makeTempLibrary(); try lib.ensureExists()
    makeImage(lib.root.appending(path: "now.png"), created: at("2026-11-14 07:00"))
    _ = try keeper(lib).catchUp(now: at("2026-11-14 08:00"))
    #expect(try LibraryScanner.scan(lib).rope.count == 1)
}

@Test func unmovableFileDoesNotBlockTheRest() throws {
    let lib = makeTempLibrary(); try lib.ensureExists()
    let locked = lib.root.appending(path: "a-locked.png")
    makeImage(locked, created: at("2026-11-14 10:00"))
    makeImage(lib.root.appending(path: "b.png"), created: at("2026-11-14 10:01"))
    try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: locked.path)
    defer { try? FileManager.default.setAttributes([.immutable: false], ofItemAtPath: locked.path) }
    _ = try keeper(lib).ingestPending()
    #expect(try LibraryScanner.scan(lib).rope.map(\.url.lastPathComponent) == ["b.png"])
    #expect(FileManager.default.fileExists(atPath: locked.path))
}

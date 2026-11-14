import Foundation
import Testing

private let t0 = Date(timeIntervalSinceReferenceDate: 1_000_000)
private let u = URL(fileURLWithPath: "/tmp/never/a.png")

@Test func nothingDeletedBeforeDelay() {
    var removed: [URL] = []
    let q = LetheQueue { removed.append($0) }
    _ = q.sink([u], now: t0)
    #expect(q.commitDue(now: t0.addingTimeInterval(4.9)) == [])
    #expect(removed.isEmpty)
}

@Test func deletedAfterDelay() {
    var removed: [URL] = []
    let q = LetheQueue { removed.append($0) }
    _ = q.sink([u], now: t0)
    #expect(q.commitDue(now: t0.addingTimeInterval(5)) == [u])
    #expect(removed == [u])
    #expect(q.commitDue(now: t0.addingTimeInterval(9)) == [])
    #expect(removed.count == 1)
}

@Test func rescueCancels() {
    var removed: [URL] = []
    let q = LetheQueue { removed.append($0) }
    let id = q.sink([u], now: t0)
    #expect(q.sinkID(containing: u) == id)
    #expect(q.rescue(id) == [u])
    #expect(q.sinkID(containing: u) == nil)
    #expect(q.commitDue(now: t0.addingTimeInterval(10)) == [])
    #expect(removed.isEmpty)
}

@Test func progressRuns0to1() {
    let q = LetheQueue { _ in }
    let id = q.sink([u], now: t0)
    #expect(q.progress(id, now: t0) == 0)
    #expect(q.progress(id, now: t0.addingTimeInterval(2.5)) == 0.5)
    #expect(q.progress(id, now: t0.addingTimeInterval(9)) == 1)
}

@Test func commitToleratesMissingFile() throws {
    let lib = makeTempLibrary(); try lib.ensureExists()
    let file = lib.rope.appending(path: "gone.png")
    makeImage(file, created: at("2026-11-14 10:00"))
    let q = LetheQueue { try Lethe.permanentlyDelete($0, paths: lib) }
    _ = q.sink([file], now: t0)
    try FileManager.default.removeItem(at: file)
    #expect(q.commitDue(now: t0.addingTimeInterval(5)) == [file])
}

@Test func failedRemovalLeavesFileAndCountsAsRescued() {
    struct Boom: Error {}
    let q = LetheQueue { _ in throw Boom() }
    _ = q.sink([u], now: t0)
    #expect(q.commitDue(now: t0.addingTimeInterval(5)) == [])
    #expect(q.sinkID(containing: u) == nil)
}

@Test func permanentDeleteRemovesEmptyBundleFolder() throws {
    let lib = makeTempLibrary(); try lib.ensureExists()
    let bundle = lib.river.appending(path: "2026-11-13 · I")
    makeImage(bundle.appending(path: "x.png"), created: at("2026-11-13 10:00"))
    try Lethe.permanentlyDelete(bundle.appending(path: "x.png"), paths: lib)
    #expect(!FileManager.default.fileExists(atPath: bundle.path))
    makeImage(lib.rope.appending(path: "y.png"), created: at("2026-11-14 10:00"))
    try Lethe.permanentlyDelete(lib.rope.appending(path: "y.png"), paths: lib)
    #expect(FileManager.default.fileExists(atPath: lib.rope.path))
}

@Test func permanentDeleteKeepsNonEmptyBundle() throws {
    let lib = makeTempLibrary(); try lib.ensureExists()
    let bundle = lib.river.appending(path: "2026-11-13 · I")
    makeImage(bundle.appending(path: "x.png"), created: at("2026-11-13 10:00"))
    makeImage(bundle.appending(path: "y.png"), created: at("2026-11-13 10:01"))
    try Lethe.permanentlyDelete(bundle.appending(path: "x.png"), paths: lib)
    #expect(names(in: bundle) == ["y.png"])
}

@Test func dropQueueDeletesNothing() throws {
    let lib = makeTempLibrary(); try lib.ensureExists()
    let file = lib.rope.appending(path: "keep.png")
    makeImage(file, created: at("2026-11-14 10:00"))
    do {
        let q = LetheQueue { try Lethe.permanentlyDelete($0, paths: lib) }
        _ = q.sink([file], now: t0)
    }
    #expect(FileManager.default.fileExists(atPath: file.path))
}

import Foundation
import Testing

@Test func standardHonorsEnvironment() {
    #expect(LibraryPaths.standard(environment: ["CLOTHESLINE_ROOT": "/tmp/x"]).root.path == "/tmp/x")
}

@Test func standardDefaultsToPictures() {
    let root = LibraryPaths.standard(environment: [:]).root
    #expect(root.path.hasSuffix("/Pictures/Clothesline"))
}

@Test func containsOnlyFilesInsideTheLibrary() {
    let lib = LibraryPaths(root: URL(fileURLWithPath: "/Users/x/Pictures/Clothesline", isDirectory: true))
    #expect(lib.contains(URL(fileURLWithPath: "/Users/x/Pictures/Clothesline/Rope/a.png")))
    #expect(lib.contains(URL(fileURLWithPath: "/Users/x/Pictures/Clothesline/River/2026-11-14 · I")))
    #expect(!lib.contains(URL(fileURLWithPath: "/Users/x/Pictures/Clothesline")))
    #expect(!lib.contains(URL(fileURLWithPath: "/Users/x/Pictures/Clothesline-old/a.png")))
    #expect(!lib.contains(URL(fileURLWithPath: "/Users/x/Desktop/a.png")))
    #expect(!lib.contains(URL(fileURLWithPath: "/Users/x/Pictures/Clothesline/Rope/../../../Desktop/a.png")))
}

@Test func filesToSinkExpandsBundleFolders() throws {
    let lib = makeTempLibrary(); try lib.ensureExists()
    let bundle = lib.river.appending(path: "2026-11-13 · I")
    makeImage(bundle.appending(path: "x.png"), created: at("2026-11-13 10:00"))
    makeImage(bundle.appending(path: "y.png"), created: at("2026-11-13 10:01"))
    makeImage(lib.rope.appending(path: "r.png"), created: at("2026-11-14 10:00"))
    let outside = FileManager.default.temporaryDirectory.appending(path: "elsewhere.png")
    let urls = lib.filesToSink([bundle, lib.rope.appending(path: "r.png"), outside, lib.rope])
    #expect(urls.map(\.lastPathComponent).sorted() == ["r.png", "x.png", "y.png"])
}

@Test func candidates() {
    #expect(FileOps.isCandidate(URL(fileURLWithPath: "/a/截屏 2026-11-14 10.00.00.PNG")))
    #expect(FileOps.isCandidate(URL(fileURLWithPath: "/a/s.heic")))
    #expect(!FileOps.isCandidate(URL(fileURLWithPath: "/a/.截屏 2026.png")))
    #expect(!FileOps.isCandidate(URL(fileURLWithPath: "/a/录屏.mov")))
    #expect(!FileOps.isCandidate(URL(fileURLWithPath: "/a/notes.txt")))
}

@Test func moveUniqueRenamesOnCollision() throws {
    let lib = makeTempLibrary(); try lib.ensureExists()
    makeImage(lib.root.appending(path: "a.png"), created: at("2026-11-14 10:00"))
    makeImage(lib.rope.appending(path: "a.png"), created: at("2026-11-14 09:00"))
    let moved = try FileOps.moveUnique(lib.root.appending(path: "a.png"), into: lib.rope)
    #expect(moved.lastPathComponent == "a (2).png")
    #expect(FileManager.default.fileExists(atPath: lib.rope.appending(path: "a.png").path))
    #expect(!FileManager.default.fileExists(atPath: lib.root.appending(path: "a.png").path))
}

@Test func movePreservesCreationDate() throws {
    let lib = makeTempLibrary(); try lib.ensureExists()
    makeImage(lib.root.appending(path: "a.png"), created: at("2026-11-12 10:00"))
    let moved = try FileOps.moveUnique(lib.root.appending(path: "a.png"), into: lib.rope)
    #expect(FileOps.creationDate(moved) == at("2026-11-12 10:00"))
}

@Test func scanSortsRopeAndRiver() throws {
    let lib = makeTempLibrary(); try lib.ensureExists()
    makeImage(lib.rope.appending(path: "b.png"), created: at("2026-11-14 11:00"))
    makeImage(lib.rope.appending(path: "a.png"), created: at("2026-11-14 10:00"))
    for name in ["2026-11-13 · I", "2026-11-14 · I"] {
        makeImage(lib.river.appending(path: name).appending(path: "x.png"), created: at("2026-11-13 08:00"))
    }
    let s = try LibraryScanner.scan(lib)
    #expect(s.rope.map(\.url.lastPathComponent) == ["a.png", "b.png"])
    #expect(s.river.map(\.id.folderName) == ["2026-11-14 · I", "2026-11-13 · I"])
    #expect(s.river[0].shots.count == 1)
}

@Test func scanIgnoresNonImagesAndDotfiles() throws {
    let lib = makeTempLibrary(); try lib.ensureExists()
    try Data().write(to: lib.root.appending(path: "notes.txt"))
    try Data().write(to: lib.root.appending(path: ".tmp.png"))
    try FileManager.default.createDirectory(at: lib.river.appending(path: "random folder"), withIntermediateDirectories: true)
    makeImage(lib.root.appending(path: "s.png"), created: at("2026-11-14 10:00"))
    let s = try LibraryScanner.scan(lib)
    #expect(s.pending.map(\.lastPathComponent) == ["s.png"])
    #expect(s.river.isEmpty)
}

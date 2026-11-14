import Foundation

/// Fixed calendar for all tests: Gregorian, UTC+8.
let testCalendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
    return c
}()

/// A fresh, empty library under the temporary directory (folders not created yet).
func makeTempLibrary() -> LibraryPaths {
    LibraryPaths(root: FileManager.default.temporaryDirectory.appending(path: "clothesline-tests/\(UUID().uuidString)"))
}

/// A valid 1×1 PNG.
let onePixelPNG = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==")!

/// Writes a 1×1 PNG at `url` (creating parent folders) and sets its creation date.
func makeImage(_ url: URL, created: Date) {
    let fm = FileManager.default
    try! fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try! onePixelPNG.write(to: url)
    try! fm.setAttributes([.creationDate: created, .modificationDate: created], ofItemAtPath: url.path)
}

/// File names in a folder's candidate images, sorted.
func names(in dir: URL) -> [String] {
    ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? [])
        .filter { !$0.hasPrefix(".") && FileOps.isCandidate(dir.appending(path: $0)) }
        .sorted()
}

/// Parses "yyyy-MM-dd HH:mm" in `testCalendar`'s time zone.
func at(_ s: String) -> Date {
    let f = DateFormatter()
    f.calendar = testCalendar
    f.timeZone = testCalendar.timeZone
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd HH:mm"
    return f.date(from: s)!
}

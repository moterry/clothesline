import Foundation

/// One-time gathering of old screenshots from the Desktop into the river (first launch, optional).
enum DesktopImport {
    static let prefixes = ["截屏", "屏幕快照", "Screenshot", "Screen Shot"]

    /// Screenshot-looking image files directly on `desktop`.
    static func find(in desktop: URL) -> [URL] {
        FileOps.candidates(in: desktop).filter { url in
            let name = url.lastPathComponent
            return prefixes.contains { name.hasPrefix($0) }
        }
    }

    /// Moves `files` into river bundles: grouped by their own day, ordered by (creation, name),
    /// split into chunks of `capacity`, continuing existing ordinals. Returns the bundles created.
    static func importAll(_ files: [URL], paths: LibraryPaths, capacity: Int, calendar: Calendar) throws -> [BundleID] {
        try paths.ensureExists()
        let shots = files.map { Shot(url: $0) }
        let byDay = Dictionary(grouping: shots) { Day($0.created, calendar: calendar) }
        let keeper = RopeKeeper(paths: paths, calendar: calendar, capacity: capacity)
        var created: [BundleID] = []
        for day in byDay.keys.sorted() {
            let ordered = byDay[day]!.sorted { ($0.created, $0.url.lastPathComponent) < ($1.created, $1.url.lastPathComponent) }
            var start = 0
            while start < ordered.count {
                let chunk = ordered[start..<min(start + max(capacity, 1), ordered.count)]
                let id = BundleID(day: day, ordinal: keeper.nextOrdinal(for: day))
                let folder = paths.river.appending(path: id.folderName, directoryHint: .isDirectory)
                for shot in chunk { try FileOps.moveUnique(shot.url, into: folder) }
                created.append(id)
                start += chunk.count
            }
        }
        return created
    }
}

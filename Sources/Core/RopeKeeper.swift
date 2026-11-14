import Foundation

enum RopeEvent: Equatable, Sendable {
    case hung(URL)
    case cut(BundleID)
}

/// Hangs new screenshots on the line and cuts the line into river bundles.
///
/// Rules:
/// - Pending files are hung in (creation date, file name) order.
/// - Before hanging, the line is cut if it holds a different day's screenshots, or if it is already full.
/// - `cutIfStale` cuts a line whose screenshots are from a day before `now` (midnight, wake, launch).
struct RopeKeeper {
    let paths: LibraryPaths
    let calendar: Calendar
    var capacity: Int

    func ingestPending() throws -> [RopeEvent] {
        var events: [RopeEvent] = []
        var rope = LibraryScanner.sortedShots(in: paths.rope)
        for shot in LibraryScanner.sortedShots(in: paths.root) {
            let day = Day(shot.created, calendar: calendar)
            if let first = rope.first, Day(first.created, calendar: calendar) != day {
                if let e = try cut() { events.append(e) }
                rope = []
            }
            if rope.count >= capacity {
                if let e = try cut() { events.append(e) }
                rope = []
            }
            // A file that cannot be moved (locked, permissions) stays in the root; the rest still hang.
            guard let moved = try? FileOps.moveUnique(shot.url, into: paths.rope) else { continue }
            rope.append(Shot(url: moved, created: shot.created))
            events.append(.hung(moved))
        }
        return events
    }

    /// Hang everything waiting, then cut the line if what it holds belongs to an earlier day
    /// (e.g. last night's screenshots caught up this morning).
    func catchUp(now: Date) throws -> [RopeEvent] {
        var events = try ingestPending()
        if let cut = try cutIfStale(now: now) { events.append(cut) }
        return events
    }

    func cutIfStale(now: Date) throws -> RopeEvent? {
        guard let first = LibraryScanner.sortedShots(in: paths.rope).first,
              Day(first.created, calendar: calendar) < Day(now, calendar: calendar) else { return nil }
        return try cut()
    }

    func cut() throws -> RopeEvent? {
        let rope = LibraryScanner.sortedShots(in: paths.rope)
        guard let first = rope.first else { return nil }
        let day = Day(first.created, calendar: calendar)
        let id = BundleID(day: day, ordinal: nextOrdinal(for: day))
        let folder = paths.river.appending(path: id.folderName, directoryHint: .isDirectory)
        for shot in rope {
            try FileOps.moveUnique(shot.url, into: folder)
        }
        return .cut(id)
    }

    /// 1 + the highest ordinal already used for `day` in the river (folders that parse as bundles).
    func nextOrdinal(for day: Day) -> Int {
        let folders = (try? FileManager.default.contentsOfDirectory(atPath: paths.river.path)) ?? []
        let used = folders.compactMap(BundleID.init(folderName:)).filter { $0.day == day }.map(\.ordinal)
        return (used.max() ?? 0) + 1
    }
}

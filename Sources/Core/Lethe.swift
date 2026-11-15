import Foundation

struct SinkID: Hashable, Sendable {
    let raw: UUID
}

/// Screenshots sinking into Lethe. Nothing is deleted until `delay` has passed *and* `commitDue` runs;
/// until then the sink can be rescued. Dropping the queue (quit, crash) deletes nothing.
final class LetheQueue {
    private struct Entry {
        let urls: [URL]
        let start: Date
    }

    let delay: TimeInterval
    private let remove: (URL) throws -> Void
    private var entries: [SinkID: Entry] = [:]

    init(delay: TimeInterval = 5, remove: @escaping (URL) throws -> Void) {
        self.delay = delay
        self.remove = remove
    }

    var isEmpty: Bool { entries.isEmpty }

    func sink(_ urls: [URL], now: Date) -> SinkID {
        let id = SinkID(raw: UUID())
        entries[id] = Entry(urls: urls, start: now)
        return id
    }

    /// Cancels a sink. Returns its files, or nil if it was not sinking.
    func rescue(_ id: SinkID) -> [URL]? {
        entries.removeValue(forKey: id)?.urls
    }

    /// Everything currently sinking, oldest first (what the Lethe pool draws).
    var sinking: [(id: SinkID, urls: [URL])] {
        entries.sorted { $0.value.start < $1.value.start }.map { (id: $0.key, urls: $0.value.urls) }
    }

    func sinkID(containing url: URL) -> SinkID? {
        entries.first { $0.value.urls.contains(url) }?.key
    }

    /// 0 at the start of the sink, 1 when it is due.
    func progress(_ id: SinkID, now: Date) -> Double {
        guard let e = entries[id] else { return 0 }
        return min(max(now.timeIntervalSince(e.start) / delay, 0), 1)
    }

    /// Permanently deletes every sink whose delay has passed. Returns the files now gone.
    /// A file that was already missing counts as deleted; any other failure leaves the file and drops it from the queue.
    func commitDue(now: Date) -> [URL] {
        var gone: [URL] = []
        for (id, entry) in entries where now.timeIntervalSince(entry.start) >= delay {
            entries[id] = nil
            for url in entry.urls {
                do {
                    try remove(url)
                    gone.append(url)
                } catch let error as CocoaError where error.code == .fileNoSuchFile {
                    gone.append(url)
                } catch {
                    continue
                }
            }
        }
        return gone
    }
}

enum Lethe {
    /// Deletes `url` for good (never via the Trash). If it was the last file of a river bundle, the bundle folder goes too.
    static func permanentlyDelete(_ url: URL, paths: LibraryPaths) throws {
        let fm = FileManager.default
        try fm.removeItem(at: url)
        let parent = url.deletingLastPathComponent()
        guard parent.deletingLastPathComponent().standardizedFileURL.path == paths.river.standardizedFileURL.path,
              BundleID(folderName: parent.lastPathComponent) != nil else { return }
        let remaining = (try? fm.contentsOfDirectory(atPath: parent.path))?.filter { $0 != ".DS_Store" } ?? []
        if remaining.isEmpty {
            try? fm.removeItem(at: parent)
        }
    }
}

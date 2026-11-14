import Foundation

/// One screenshot file.
struct Shot: Hashable, Identifiable, Sendable {
    let url: URL
    let created: Date
    var id: URL { url }

    init(url: URL, created: Date) {
        self.url = url
        self.created = created
    }

    init(url: URL) {
        self.init(url: url, created: FileOps.creationDate(url))
    }
}

/// One bundle in the river (one cut line).
struct RiverBundle: Identifiable, Sendable {
    let id: BundleID
    let url: URL
    /// Oldest first.
    let shots: [Shot]
}

/// Everything on disk at one moment.
struct LibrarySnapshot: Sendable {
    /// Today's line, oldest first.
    let rope: [Shot]
    /// Newest bundle first.
    let river: [RiverBundle]
    /// Screenshots in the root waiting to be hung, oldest first.
    let pending: [URL]

    static let empty = LibrarySnapshot(rope: [], river: [], pending: [])
}

enum LibraryScanner {
    static func scan(_ paths: LibraryPaths) throws -> LibrarySnapshot {
        let rope = sortedShots(in: paths.rope)
        let pending = sortedShots(in: paths.root).map(\.url)
        let folders = (try? FileManager.default.contentsOfDirectory(at: paths.river, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        let river = folders.compactMap { url -> RiverBundle? in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
                  let id = BundleID(folderName: url.lastPathComponent) else { return nil }
            return RiverBundle(id: id, url: url, shots: sortedShots(in: url))
        }
        .sorted { $0.id < $1.id }
        return LibrarySnapshot(rope: rope, river: river, pending: pending)
    }

    /// Candidate images in `dir`, ordered by (creation date, file name).
    static func sortedShots(in dir: URL) -> [Shot] {
        FileOps.candidates(in: dir)
            .map { Shot(url: $0) }
            .sorted { ($0.created, $0.url.lastPathComponent) < ($1.created, $1.url.lastPathComponent) }
    }
}

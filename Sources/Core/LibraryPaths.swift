import Foundation

/// Where Clothesline keeps its screenshots. The folder structure on disk *is* the state:
/// `root/` receives new system screenshots, `Rope/` holds today's line, `River/` holds one folder per bundle.
struct LibraryPaths: Sendable {
    let root: URL
    var rope: URL { root.appending(path: "Rope", directoryHint: .isDirectory) }
    var river: URL { root.appending(path: "River", directoryHint: .isDirectory) }

    init(root: URL) {
        self.root = root
    }

    /// `~/Pictures/Clothesline`, or `$CLOTHESLINE_ROOT` when set.
    static func standard(environment: [String: String] = ProcessInfo.processInfo.environment) -> LibraryPaths {
        if let override = environment["CLOTHESLINE_ROOT"], !override.isEmpty {
            return LibraryPaths(root: URL(fileURLWithPath: override, isDirectory: true))
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        return LibraryPaths(root: home.appending(path: "Pictures/Clothesline", directoryHint: .isDirectory))
    }

    /// True for anything strictly inside the library root (after resolving `..`). Lethe only ever touches these.
    func contains(_ url: URL) -> Bool {
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        return path.hasPrefix(rootPath + "/") && path.count > rootPath.count + 1
    }

    /// What a drop onto Lethe would delete: screenshot files inside the library, with river bundle
    /// folders expanded to their screenshots. Anything else (outside files, the Rope folder itself) is ignored.
    func filesToSink(_ urls: [URL]) -> [URL] {
        var out: [URL] = []
        for url in urls where contains(url) {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { continue }
            if isDir.boolValue {
                let parent = url.deletingLastPathComponent().standardizedFileURL.path
                if parent == river.standardizedFileURL.path, BundleID(folderName: url.lastPathComponent) != nil {
                    out += FileOps.candidates(in: url)
                }
            } else if FileOps.isCandidate(url) {
                out.append(url)
            }
        }
        return out
    }

    func ensureExists() throws {
        for dir in [root, rope, river] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
}

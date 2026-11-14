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

    func ensureExists() throws {
        for dir in [root, rope, river] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
}

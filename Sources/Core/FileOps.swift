import Foundation

/// File helpers. Nothing here ever overwrites an existing file.
enum FileOps {
    static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "tiff", "tif", "pdf"]

    /// An image file that can be a screenshot: known image extension, not a hidden/temporary file.
    static func isCandidate(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        guard !name.hasPrefix(".") else { return false }
        return imageExtensions.contains(url.pathExtension.lowercased())
    }

    static func creationDate(_ url: URL) -> Date {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attrs?[.creationDate] as? Date) ?? (attrs?[.modificationDate] as? Date) ?? .distantPast
    }

    /// Moves `src` into `dir`, renaming to `name (2).ext`, `name (3).ext`, … if the name is taken.
    @discardableResult
    static func moveUnique(_ src: URL, into dir: URL) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let base = src.deletingPathExtension().lastPathComponent
        let ext = src.pathExtension
        var candidate = dir.appending(path: src.lastPathComponent)
        var n = 2
        while fm.fileExists(atPath: candidate.path) {
            let name = ext.isEmpty ? "\(base) (\(n))" : "\(base) (\(n)).\(ext)"
            candidate = dir.appending(path: name)
            n += 1
        }
        try fm.moveItem(at: src, to: candidate)
        return candidate
    }

    /// Candidate image files directly inside `dir`, unsorted.
    static func candidates(in dir: URL) -> [URL] {
        let items = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isRegularFileKey])) ?? []
        return items.filter { url in
            isCandidate(url) && ((try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false)
        }
    }
}

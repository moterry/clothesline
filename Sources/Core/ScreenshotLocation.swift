import Foundation

/// Reads and writes `defaults … com.apple.screencapture location`.
protocol DefaultsShell {
    func readLocation() -> String?
    func writeLocation(_ path: String)
    func deleteLocation()
}

/// The real thing: runs /usr/bin/defaults, then restarts SystemUIServer so the change takes effect.
struct SystemDefaultsShell: DefaultsShell {
    func readLocation() -> String? {
        let out = run("/usr/bin/defaults", ["read", "com.apple.screencapture", "location"])
        guard out.status == 0 else { return nil }
        let value = out.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    func writeLocation(_ path: String) {
        _ = run("/usr/bin/defaults", ["write", "com.apple.screencapture", "location", path])
        _ = run("/usr/bin/killall", ["SystemUIServer"])
    }

    func deleteLocation() {
        _ = run("/usr/bin/defaults", ["delete", "com.apple.screencapture", "location"])
        _ = run("/usr/bin/killall", ["SystemUIServer"])
    }

    private func run(_ tool: String, _ args: [String]) -> (status: Int32, stdout: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        do { try p.run() } catch { return (-1, "") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus, String(decoding: data, as: UTF8.self))
    }
}

/// Points system screenshots at Clothesline's folder, remembering where they went before so it can be undone exactly.
final class ScreenshotLocation {
    private static let originalKey = "originalScreenshotLocation"
    private static let wasUnsetKey = "originalScreenshotLocationWasUnset"
    private static let recordedKey = "originalScreenshotLocationRecorded"

    private let shell: DefaultsShell
    private let memory: UserDefaults

    init(shell: DefaultsShell, memory: UserDefaults) {
        self.shell = shell
        self.memory = memory
    }

    func isAdopted(_ folder: URL) -> Bool {
        shell.readLocation().map(Self.normalize) == Self.normalize(folder.path)
    }

    func adopt(_ folder: URL) {
        if !isAdopted(folder) && !memory.bool(forKey: Self.recordedKey) {
            if let current = shell.readLocation() {
                memory.set(current, forKey: Self.originalKey)
                memory.set(false, forKey: Self.wasUnsetKey)
            } else {
                memory.removeObject(forKey: Self.originalKey)
                memory.set(true, forKey: Self.wasUnsetKey)
            }
            memory.set(true, forKey: Self.recordedKey)
        }
        shell.writeLocation(folder.path)
    }

    /// Puts back the location remembered by `adopt`. Does nothing if `adopt` never ran.
    func restore() {
        guard memory.bool(forKey: Self.recordedKey) else { return }
        if memory.bool(forKey: Self.wasUnsetKey) {
            shell.deleteLocation()
        } else if let original = memory.string(forKey: Self.originalKey) {
            shell.writeLocation(original)
        }
        memory.removeObject(forKey: Self.recordedKey)
        memory.removeObject(forKey: Self.originalKey)
        memory.removeObject(forKey: Self.wasUnsetKey)
    }

    private static func normalize(_ path: String) -> String {
        var p = (path as NSString).expandingTildeInPath
        while p.count > 1 && p.hasSuffix("/") { p.removeLast() }
        return p
    }
}

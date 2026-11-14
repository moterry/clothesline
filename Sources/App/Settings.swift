import Foundation

/// User preferences (UserDefaults).
final class Settings {
    static let capacities = [8, 12, 16]
    private let d: UserDefaults

    init(defaults: UserDefaults = .standard) {
        d = defaults
    }

    var capacity: Int {
        get { let v = d.integer(forKey: "capacity"); return Self.capacities.contains(v) ? v : 12 }
        set { d.set(newValue, forKey: "capacity") }
    }

    var paused: Bool {
        get { d.bool(forKey: "paused") }
        set { d.set(newValue, forKey: "paused") }
    }

    var hasOnboarded: Bool {
        get { d.bool(forKey: "hasOnboarded") }
        set { d.set(newValue, forKey: "hasOnboarded") }
    }

    /// On by default.
    var launchAtLogin: Bool {
        get { d.object(forKey: "launchAtLogin") as? Bool ?? true }
        set { d.set(newValue, forKey: "launchAtLogin") }
    }
}

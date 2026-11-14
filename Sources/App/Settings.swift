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

    /// Set after the first automatic login-item registration, so a later "off" in System Settings sticks.
    var loginItemRegisteredOnce: Bool {
        get { d.bool(forKey: "loginItemRegisteredOnce") }
        set { d.set(newValue, forKey: "loginItemRegisteredOnce") }
    }

    /// On by default.
    var launchAtLogin: Bool {
        get { d.object(forKey: "launchAtLogin") as? Bool ?? true }
        set { d.set(newValue, forKey: "launchAtLogin") }
    }
}

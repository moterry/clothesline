import AppKit

/// A borderless, transparent strip that lives at the desktop layer:
/// above the wallpaper and desktop icons, below every app window.
/// "Summoned" temporarily lifts it above all windows.
final class StripWindow: NSPanel {
    static let restingLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
    static let summonedLevel = NSWindow.Level.floating

    init(frame: NSRect, content: NSView) {
        super.init(contentRect: frame,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = Self.restingLevel
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        isMovable = false
        acceptsMouseMovedEvents = true
        contentView = content
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func setSummoned(_ on: Bool) {
        level = on ? Self.summonedLevel : Self.restingLevel
        orderFrontRegardless()
    }
}

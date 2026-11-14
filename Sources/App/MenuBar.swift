import AppKit
import ServiceManagement

/// The small arc in the menu bar and its menu.
@MainActor
final class MenuBar: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let model: AppModel
    private let location: ScreenshotLocation?
    private let onSummon: () -> Void
    private let onCatchAgain: () -> Void

    init(model: AppModel, location: ScreenshotLocation?, onSummon: @escaping () -> Void, onCatchAgain: @escaping () -> Void) {
        self.model = model
        self.location = location
        self.onSummon = onSummon
        self.onCatchAgain = onCatchAgain
        super.init()
        item.button?.image = Self.arcImage()
        item.button?.toolTip = "晾衣绳"
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
    }

    /// A thin hanging arc, drawn as a template image so it follows the menu bar's colour.
    static func arcImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 12), flipped: true) { _ in
            let p = NSBezierPath()
            p.move(to: NSPoint(x: 1.5, y: 2.5))
            p.curve(to: NSPoint(x: 16.5, y: 2.5), controlPoint1: NSPoint(x: 6, y: 10.5), controlPoint2: NSPoint(x: 12, y: 10.5))
            p.lineWidth = 1.3
            p.lineCapStyle = .round
            NSColor.black.setStroke()
            p.stroke()
            for x in [6.0, 9.0, 12.0] {
                NSBezierPath(rect: NSRect(x: x - 0.6, y: 6.2, width: 1.2, height: 3.2)).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let settings = model.settings

        let summon = add(menu, "召唤晾衣绳", #selector(summon))
        summon.keyEquivalent = "l"
        summon.keyEquivalentModifierMask = [.control, .option]

        add(menu, settings.paused ? "继续接住截图" : "暂停接住截图", #selector(togglePause))
        add(menu, "打开截图文件夹", #selector(openFolder))

        let lengthItem = NSMenuItem(title: "绳长", action: nil, keyEquivalent: "")
        let lengths = NSMenu()
        for n in Settings.capacities {
            let i = NSMenuItem(title: "\(n)", action: #selector(setLength(_:)), keyEquivalent: "")
            i.target = self
            i.tag = n
            i.state = settings.capacity == n ? .on : .off
            lengths.addItem(i)
        }
        lengthItem.submenu = lengths
        menu.addItem(lengthItem)

        let login = add(menu, "开机启动", #selector(toggleLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        login.isEnabled = Bundle.main.bundleIdentifier != nil

        menu.addItem(.separator())
        if let location {
            if location.isAdopted(model.paths.root) {
                add(menu, "恢复系统截图位置", #selector(restoreLocation))
            } else {
                add(menu, "重新接住截图", #selector(catchAgain))
            }
        }
        menu.addItem(.separator())
        add(menu, "退出", #selector(quit))
    }

    @discardableResult
    private func add(_ menu: NSMenu, _ title: String, _ action: Selector) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: "")
        i.target = self
        menu.addItem(i)
        return i
    }

    @objc private func summon() { onSummon() }

    @objc private func togglePause() {
        model.settings.paused.toggle()
        if !model.settings.paused { model.ingest() }
    }

    @objc private func openFolder() { NSWorkspace.shared.open(model.paths.root) }

    @objc private func setLength(_ sender: NSMenuItem) {
        model.settings.capacity = sender.tag
        model.refresh()
    }

    @objc private func toggleLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
                model.settings.launchAtLogin = false
            } else {
                try service.register()
                model.settings.launchAtLogin = true
            }
        } catch {
            NSSound.beep()
        }
    }

    @objc private func restoreLocation() { location?.restore() }

    @objc private func catchAgain() { onCatchAgain() }

    @objc private func quit() { NSApp.terminate(nil) }
}

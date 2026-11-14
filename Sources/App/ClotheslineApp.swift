import AppKit
import SwiftUI

@main
struct ClotheslineApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = Settings()
    lazy var model = AppModel(paths: LibraryPaths.standard(), settings: settings)

    private var top: StripWindow!
    private var bottom: StripWindow!
    private var hotKey: HotKey?
    private var watcher: FolderWatcher?
    private var keyMonitor: Any?
    private var observers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.start()
        buildStrips()

        watcher = FolderWatcher(url: model.paths.root) { [weak self] in
            MainActor.assumeIsolated { self?.model.ingest() }
        }
        watcher?.start()

        hotKey = HotKey(keyCode: HotKey.summonKeyCode, modifiers: HotKey.summonModifiers) { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.model.setSummoned(!self.model.summoned)
            }
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            guard e.keyCode == 53, let self else { return e } // Esc
            if self.model.expanded != nil { self.model.expanded = nil; return nil }
            if self.model.summoned { self.model.setSummoned(false); return nil }
            return e
        }
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.layoutStrips() }
        })

        let args = CommandLine.arguments
        if args.contains("--summon") { model.setSummoned(true) }
        if let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count {
            let dir = URL(fileURLWithPath: args[i + 1])
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.writeSnapshots(to: dir)
                NSApp.terminate(nil)
            }
        }
    }

    // MARK: Strips

    private func buildStrips() {
        top = StripWindow(frame: .zero, content: NSHostingView(rootView: RopeView(model: model)))
        bottom = StripWindow(frame: .zero, content: NSHostingView(rootView: RiverStripView(model: model)))
        layoutStrips()
        top.orderFrontRegardless()
        bottom.orderFrontRegardless()

        model.onSummonChange = { [weak self] on in
            guard let self else { return }
            self.top.setSummoned(on)
            self.bottom.setSummoned(on)
            if on { NSApp.activate(ignoringOtherApps: true); self.bottom.makeKey() }
        }
        model.onExpandChange = { [weak self] _ in self?.layoutStrips() }
    }

    private func layoutStrips() {
        guard let screen = NSScreen.main else { return }
        let full = screen.frame, visible = screen.visibleFrame
        top.setFrame(NSRect(x: full.minX, y: visible.maxY - Theme.topStripHeight,
                            width: full.width, height: Theme.topStripHeight), display: true)
        let h = model.expanded == nil ? Theme.bottomStripHeight : Theme.bottomStripExpandedHeight
        bottom.setFrame(NSRect(x: full.minX, y: visible.minY, width: full.width, height: h), display: true)
    }

    // MARK: Debug snapshots (no Screen Recording permission needed: renders our own views)

    private func writeSnapshots(to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (name, window) in [("top", top!), ("bottom", bottom!)] {
            guard let view = window.contentView else { continue }
            let bounds = view.bounds
            guard let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else { continue }
            view.cacheDisplay(in: bounds, to: rep)
            let composed = NSImage(size: bounds.size, flipped: false) { r in
                NSColor(calibratedRed: 0.925, green: 0.91, blue: 0.885, alpha: 1).setFill()
                r.fill()
                rep.draw(in: r)
                return true
            }
            if let tiff = composed.tiffRepresentation, let bmp = NSBitmapImageRep(data: tiff),
               let png = bmp.representation(using: .png, properties: [:]) {
                try? png.write(to: dir.appending(path: "\(name).png"))
            }
        }
    }
}

/// Bottom strip host. Replaced by the full river in Task 10.
struct RiverStripView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        LinearGradient(colors: [Theme.water.opacity(0), Theme.water.opacity(Theme.waterOpacity), Theme.water.opacity(0)],
                       startPoint: .top, endPoint: .bottom)
            .frame(height: Theme.riverHeight)
            .frame(maxHeight: .infinity, alignment: .bottom)
    }
}

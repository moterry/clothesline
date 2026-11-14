import AppKit
import SwiftUI

// PROOF OF CONCEPT (Task 2) — replaced by the real strips in Task 8.

@main
struct ClotheslineApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = PoCDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

final class PoCDelegate: NSObject, NSApplicationDelegate {
    var top: StripWindow!
    var bottom: StripWindow!
    var hotKey: HotKey!
    var escMonitor: Any?
    var summoned = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let screen = NSScreen.main!
        let visible = screen.visibleFrame
        let full = screen.frame
        let imageURL = Self.writeSampleImage()

        let topFrame = NSRect(x: full.minX, y: visible.maxY - 300, width: full.width, height: 300)
        top = StripWindow(frame: topFrame, content: NSHostingView(rootView: PoCTopView(url: imageURL)))
        let bottomFrame = NSRect(x: full.minX, y: visible.minY, width: full.width, height: 170)
        bottom = StripWindow(frame: bottomFrame, content: NSHostingView(rootView: PoCBottomView()))
        top.orderFrontRegardless()
        bottom.orderFrontRegardless()

        hotKey = HotKey(keyCode: HotKey.summonKeyCode, modifiers: HotKey.summonModifiers) { [weak self] in
            self?.setSummoned(!(self?.summoned ?? false))
        }
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            if e.keyCode == 53, self?.summoned == true { self?.setSummoned(false); return nil }
            return e
        }
    }

    func setSummoned(_ on: Bool) {
        summoned = on
        top.setSummoned(on)
        bottom.setSummoned(on)
        if on { NSApp.activate(ignoringOtherApps: true); top.makeKey() }
    }

    static func writeSampleImage() -> URL {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appending(path: "build/poc.png")
        let image = NSImage(size: NSSize(width: 300, height: 200), flipped: false) { r in
            NSColor(calibratedRed: 0.24, green: 0.35, blue: 0.5, alpha: 1).setFill(); r.fill()
            NSColor(calibratedRed: 0.88, green: 0.48, blue: 0.37, alpha: 1).setFill()
            NSRect(x: 40, y: 40, width: 80, height: 120).fill()
            return true
        }
        let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
        try? rep.representation(using: .png, properties: [:])!.write(to: url)
        return url
    }
}

struct PoCTopView: View {
    let url: URL
    @State private var hovering = false
    var body: some View {
        VStack(spacing: 8) {
            Text("HODIE · PoC").font(.custom("Palatino-Roman", size: 12)).tracking(3).foregroundStyle(Color(white: 0.45))
            Image(nsImage: NSImage(contentsOf: url) ?? NSImage())
                .resizable().frame(width: 150, height: 100)
                .padding(3).background(.white)
                .shadow(color: .black.opacity(0.2), radius: 3, y: 3)
                .scaleEffect(hovering ? 1.15 : 1)
                .animation(.easeOut(duration: 0.2), value: hovering)
                .onHover { hovering = $0 }
                .onDrag { NSItemProvider(contentsOf: url)! }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 30)
    }
}

struct PoCBottomView: View {
    var body: some View {
        LinearGradient(colors: [Color(red: 0.31, green: 0.44, blue: 0.56).opacity(0),
                                Color(red: 0.31, green: 0.44, blue: 0.56).opacity(0.16),
                                Color(red: 0.31, green: 0.44, blue: 0.56).opacity(0)],
                       startPoint: .top, endPoint: .bottom)
            .frame(height: 130)
            .frame(maxHeight: .infinity, alignment: .bottom)
    }
}

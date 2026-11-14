import AppKit
import SwiftUI

/// First launch (and "catch screenshots again"): consent to move the screenshot location,
/// then an optional one-time gathering of old Desktop screenshots into the river.
@MainActor
final class Onboarding {
    private var window: NSWindow?

    func show(model: AppModel, location: ScreenshotLocation, askImport: Bool, onDone: @escaping () -> Void) {
        let desktop = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Desktop")
        let view = OnboardingView(
            countDesktop: { askImport ? DesktopImport.find(in: desktop).count : 0 },
            adopt: {
                location.adopt(model.paths.root)
            },
            importDesktop: {
                _ = try? DesktopImport.importAll(DesktopImport.find(in: desktop), paths: model.paths,
                                                 capacity: model.settings.capacity, calendar: model.calendar)
                model.refresh()
            },
            finish: { [weak self] in
                model.settings.hasOnboarded = true
                self?.window?.close()
                self?.window = nil
                onDone()
            })
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 360),
                         styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.isReleasedWhenClosed = false
        w.backgroundColor = .white
        w.contentView = NSHostingView(rootView: view)
        w.center()
        window = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }
}

private struct OnboardingView: View {
    /// Called only after consent, so macOS asks for Desktop access no earlier than that.
    let countDesktop: () -> Int
    let adopt: () -> Void
    let importDesktop: () -> Void
    let finish: () -> Void

    @State private var step = 0
    @State private var desktopCount = 0

    var body: some View {
        VStack(spacing: 22) {
            ArcMotif().frame(width: 220, height: 34)

            if step == 0 {
                VStack(alignment: .leading, spacing: 10) {
                    line("绳", "今天的截图挂在这里")
                    line("河", "过去的截图永远在这里")
                    line("忘川", "只有你亲手放进去的才会被遗忘")
                    line("⌃⌥L", "随时召唤晾衣绳")
                }
                Text("晾衣绳会把系统截图的保存位置改到「图片 › Clothesline」。随时可以在菜单栏里恢复。")
                    .font(Theme.song(12)).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 14) {
                    Button("暂不") { finish() }
                    Button("把截图接到晾衣绳") {
                        adopt()
                        desktopCount = countDesktop()
                        if desktopCount > 0 { step = 1 } else { finish() }
                    }
                }
            } else {
                Text("桌面上有 \(desktopCount) 张旧截图，收进记忆之河？")
                    .font(Theme.song(15)).foregroundStyle(Theme.line)
                Text("它们会按各自的日期成束，从桌面移进河里。")
                    .font(Theme.song(12)).foregroundStyle(Theme.ink)
                HStack(spacing: 14) {
                    Button("暂不") { finish() }
                    Button("收进河里") { importDesktop(); finish() }
                    }
            }
        }
        .padding(36)
        .frame(width: 460, height: 360)
        .background(Color.white)
    }

    private func line(_ head: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(head).font(Theme.song(15)).foregroundStyle(Theme.line).frame(width: 52, alignment: .trailing)
            Text(text).font(Theme.song(14)).foregroundStyle(Theme.ink)
        }
    }
}

/// The line motif: a sagging thread with three pegs.
private struct ArcMotif: View {
    var body: some View {
        Canvas { ctx, size in
            var p = Path()
            p.move(to: CGPoint(x: 2, y: 4))
            p.addQuadCurve(to: CGPoint(x: size.width - 2, y: 4), control: CGPoint(x: size.width / 2, y: size.height + 6))
            ctx.stroke(p, with: .color(Theme.line), lineWidth: 1)
            for t in [0.3, 0.5, 0.7] {
                let x = 2 + (size.width - 4) * t
                let y = 4 + 2 * (size.height + 2) * t * (1 - t)
                ctx.fill(Path(roundedRect: CGRect(x: x - 2, y: y - 5, width: 4, height: 11), cornerRadius: 1), with: .color(Theme.peg))
            }
        }
    }
}

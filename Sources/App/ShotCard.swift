import AppKit
import SwiftUI

/// One framed screenshot: thumbnail, 3pt white frame, soft shadow.
struct ShotCard: View {
    let shot: Shot
    let size: CGSize
    var opacity: Double = 1
    var saturation: Double = 1
    var shadow = true

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                Rectangle().fill(Color(white: 0.93))
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .saturation(saturation)
        .padding(Theme.frame)
        .background(Color.white)
        .shadow(color: .black.opacity(shadow ? 0.2 : 0), radius: 3, y: 3)
        .opacity(opacity)
        .onAppear { image = ThumbnailCache.shared.cached(shot.url, size: size) }
        .task(id: "\(shot.url.path)|\(size.width)x\(size.height)") {
            if image == nil { image = await ThumbnailCache.shared.image(for: shot.url, size: size) }
        }
    }
}

/// What every screenshot on the line or in an unrolled bundle can do:
/// hover to enlarge, click for Quick Look, drag out as a file (it stays put), right-click menu.
/// A screenshot that is sinking into Lethe is rescued by a click or a drag instead.
struct ShotInteractions: ViewModifier {
    @ObservedObject var model: AppModel
    let shot: Shot
    let size: CGSize
    /// All screenshots in the same group, for Quick Look's arrow keys.
    var siblings: [URL] = []

    @State private var hovering = false

    func body(content: Content) -> some View {
        let url = shot.url
        content
            .overlay(alignment: .top) {
                if hovering && !model.isDragging && !model.isSinking(url) {
                    ShotCard(shot: shot, size: CGSize(width: size.width * 2, height: size.height * 2))
                        .offset(y: size.height * 0.35)
                        .allowsHitTesting(false)
                        .transition(.opacity.combined(with: .scale(scale: 0.6, anchor: .top)))
                }
            }
            .zIndex(hovering ? 10 : 0)
            .animation(.easeOut(duration: 0.18), value: hovering)
            .onHover { on in
                hovering = on
                if on { model.hovered = url } else if model.hovered == url { model.hovered = nil }
            }
            .onTapGesture {
                if model.isSinking(url) {
                    model.rescue(url)
                } else {
                    let group = siblings.isEmpty ? [url] : siblings
                    QuickLook.shared.show(group, index: group.firstIndex(of: url) ?? 0)
                }
            }
            .onDrag {
                if model.isSinking(url) { model.rescue(url) }
                model.beginDrag([url])
                return NSItemProvider(contentsOf: url) ?? NSItemProvider()
            }
            .contextMenu {
                Button("快速查看") { QuickLook.shared.show([url], index: 0) }
                Button("在 Finder 中显示") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                Button("拷贝") { ShotActions.copy(url) }
                Divider()
                Button("沉入忘川") { model.sink([url]) }
            }
    }
}

enum ShotActions {
    static func copy(_ url: URL) {
        let pb = NSPasteboard.general
        pb.clearContents()
        var items: [NSPasteboardWriting] = [url as NSURL]
        if let image = NSImage(contentsOf: url) { items.append(image) }
        pb.writeObjects(items)
    }
}

extension View {
    func shotInteractions(model: AppModel, shot: Shot, size: CGSize, siblings: [URL] = []) -> some View {
        modifier(ShotInteractions(model: model, shot: shot, size: size, siblings: siblings))
    }
}

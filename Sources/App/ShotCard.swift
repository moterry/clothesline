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

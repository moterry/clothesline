import AppKit
import ImageIO
import QuickLookThumbnailing

/// Thumbnails (Quick Look) and pixel sizes (image header only), both cached.
@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let images = NSCache<NSString, NSImage>()
    private var sizes: [URL: CGSize] = [:]

    private func key(_ url: URL, _ size: CGSize) -> NSString {
        "\(url.path)|\(Int(size.width))x\(Int(size.height))" as NSString
    }

    func cached(_ url: URL, size: CGSize) -> NSImage? {
        images.object(forKey: key(url, size))
    }

    func image(for url: URL, size: CGSize) async -> NSImage? {
        if let hit = cached(url, size: size) { return hit }
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let request = QLThumbnailGenerator.Request(fileAt: url, size: size, scale: scale, representationTypes: .thumbnail)
        let image: NSImage? = await withCheckedContinuation { cont in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { rep, _ in
                cont.resume(returning: rep?.nsImage)
            }
        }
        if let image { images.setObject(image, forKey: key(url, size)) }
        return image
    }

    /// Synchronous load used for snapshot rendering.
    func loadNow(_ url: URL, size: CGSize) -> NSImage? {
        if let hit = cached(url, size: size) { return hit }
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceThumbnailMaxPixelSize: max(size.width, size.height) * 2,
                  kCGImageSourceCreateThumbnailWithTransform: true,
              ] as CFDictionary) else { return nil }
        let image = NSImage(cgImage: cg, size: size)
        images.setObject(image, forKey: key(url, size))
        return image
    }

    /// Pixel dimensions from the image header (no full decode).
    func pixelSize(_ url: URL) -> CGSize {
        if let s = sizes[url] { return s }
        var s = CGSize.zero
        if let src = CGImageSourceCreateWithURL(url as CFURL, nil),
           let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
           let w = props[kCGImagePropertyPixelWidth] as? Int, let h = props[kCGImagePropertyPixelHeight] as? Int {
            s = CGSize(width: w, height: h)
        }
        sizes[url] = s
        return s
    }
}

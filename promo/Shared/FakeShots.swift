import AppKit
import CoreGraphics

/// Procedurally drawn "screenshots" (chat, code, chart, …) so demos and promo material
/// never use anyone's real screen or copyrighted artwork.
enum FakeShots {
    static let kinds = ["chat", "code", "chart", "doc", "photo", "map", "table", "design", "terminal", "calendar"]

    /// Natural pixel size for a kind (screenshots vary in aspect ratio).
    static func size(_ kind: String) -> CGSize {
        switch kind {
        case "chat": return CGSize(width: 420, height: 600)
        case "doc": return CGSize(width: 480, height: 620)
        case "code", "terminal": return CGSize(width: 760, height: 470)
        case "photo": return CGSize(width: 720, height: 480)
        default: return CGSize(width: 680, height: 460)
        }
    }

    static func image(_ kind: String, seed: UInt64) -> CGImage {
        let s = size(kind)
        let ctx = CGContext(data: nil, width: Int(s.width), height: Int(s.height), bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.translateBy(x: 0, y: s.height)
        ctx.scaleBy(x: 1, y: -1) // y down
        draw(kind, in: ctx, size: s, seed: seed)
        return ctx.makeImage()!
    }

    static func writePNG(_ image: CGImage, to url: URL) {
        let rep = NSBitmapImageRep(cgImage: image)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }

    // MARK: Drawing

    private struct RNG {
        var s: UInt64
        mutating func next() -> CGFloat {
            s = s &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return CGFloat(s >> 11) / CGFloat(1 << 53)
        }
    }

    private static func c(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
                blue: CGFloat(hex & 0xff) / 255, alpha: a)
    }

    private static func rect(_ ctx: CGContext, _ r: CGRect, _ color: CGColor, radius: CGFloat = 0) {
        ctx.setFillColor(color)
        ctx.addPath(CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil))
        ctx.fillPath()
    }

    private static func titleBar(_ ctx: CGContext, _ w: CGFloat, dark: Bool = false) {
        rect(ctx, CGRect(x: 0, y: 0, width: w, height: 34), c(dark ? 0x2a2c33 : 0xececef))
        for (i, col) in [0xff5f57, 0xfebc2e, 0x28c840].enumerated() {
            ctx.setFillColor(c(UInt32(col)))
            ctx.fillEllipse(in: CGRect(x: 14 + CGFloat(i) * 20, y: 11, width: 12, height: 12))
        }
    }

    private static func draw(_ kind: String, in ctx: CGContext, size s: CGSize, seed: UInt64) {
        var r = RNG(s: seed &* 0x9E37_79B9_7F4A_7C15 &+ 1)
        let w = s.width, h = s.height
        switch kind {
        case "chat":
            rect(ctx, CGRect(origin: .zero, size: s), c(0xffffff))
            titleBar(ctx, w)
            var y: CGFloat = 60
            for i in 0..<7 {
                let mine = i % 2 == 1
                let bw = w * (0.35 + r.next() * 0.3), bh: CGFloat = 38 + (r.next() > 0.6 ? 26 : 0)
                rect(ctx, CGRect(x: mine ? w - bw - 22 : 22, y: y, width: bw, height: bh), c(mine ? 0x5b9cf5 : 0xe6e6ea), radius: 18)
                y += bh + 22
            }
        case "code", "terminal":
            let dark = kind == "terminal" ? 0x111214 : 0x1f2128
            rect(ctx, CGRect(origin: .zero, size: s), c(UInt32(dark)))
            titleBar(ctx, w, dark: true)
            let cols: [UInt32] = kind == "terminal" ? [0x9fe2a0, 0xd0d0d0, 0x7fb3ff] : [0xc792ea, 0x82aaff, 0xc3e88d, 0xf78c6c, 0x89ddff, 0x676e95]
            var y: CGFloat = 56
            while y < h - 30 {
                var x: CGFloat = 26 + CGFloat(Int(r.next() * 3)) * 28
                for _ in 0..<(1 + Int(r.next() * 4)) {
                    let lw = 30 + r.next() * 120
                    if x + lw > w - 20 { break }
                    rect(ctx, CGRect(x: x, y: y, width: lw, height: 11), c(cols[Int(r.next() * CGFloat(cols.count))]), radius: 3)
                    x += lw + 12
                }
                y += 26
            }
        case "chart":
            rect(ctx, CGRect(origin: .zero, size: s), c(0xfbfbfa))
            titleBar(ctx, w)
            let base = h - 50
            for i in 0..<9 {
                let bh = (h - 140) * (0.2 + r.next() * 0.75)
                rect(ctx, CGRect(x: 50 + CGFloat(i) * (w - 100) / 9, y: base - bh, width: (w - 100) / 9 * 0.62, height: bh),
                     c(i == 5 ? 0xe07a5f : 0x3d5a80), radius: 3)
            }
            ctx.setStrokeColor(c(0x999999)); ctx.setLineWidth(1.5)
            ctx.move(to: CGPoint(x: 40, y: base)); ctx.addLine(to: CGPoint(x: w - 40, y: base)); ctx.strokePath()
        case "doc":
            rect(ctx, CGRect(origin: .zero, size: s), c(0xfbfaf6))
            titleBar(ctx, w)
            rect(ctx, CGRect(x: 44, y: 66, width: w * 0.55, height: 26), c(0x333333), radius: 3)
            var y: CGFloat = 120
            while y < h - 40 {
                rect(ctx, CGRect(x: 44, y: y, width: (w - 88) * (0.6 + r.next() * 0.4), height: 11), c(0xc4c4c4), radius: 3)
                y += r.next() > 0.85 ? 40 : 24
            }
        case "photo":
            let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [c(0xf3c9a0), c(0x8fb3c9)] as CFArray, locations: [0, 1])!
            ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: h), options: [])
            ctx.setFillColor(c(0xfff3d6)); ctx.fillEllipse(in: CGRect(x: w * 0.72, y: h * 0.14, width: h * 0.16, height: h * 0.16))
            for (k, col) in [(0.0, 0x6d7f91), (1.0, 0x4a5a6a)].enumerated() {
                ctx.setFillColor(c(UInt32(col.1)))
                ctx.move(to: CGPoint(x: 0, y: h))
                var x: CGFloat = 0
                while x <= w {
                    ctx.addLine(to: CGPoint(x: x, y: h * (0.45 + 0.12 * CGFloat(k)) + r.next() * h * 0.22))
                    x += w / 6
                }
                ctx.addLine(to: CGPoint(x: w, y: h)); ctx.closePath(); ctx.fillPath()
            }
        case "map":
            rect(ctx, CGRect(origin: .zero, size: s), c(0xe9efe3))
            rect(ctx, CGRect(x: w * 0.62, y: h * 0.1, width: w * 0.3, height: h * 0.3), c(0xcfe0f0), radius: 30)
            ctx.setStrokeColor(c(0xffffff)); ctx.setLineWidth(18); ctx.setLineCap(.round)
            ctx.move(to: CGPoint(x: 0, y: h * 0.62)); ctx.addCurve(to: CGPoint(x: w, y: h * 0.5), control1: CGPoint(x: w * 0.3, y: h * 0.35), control2: CGPoint(x: w * 0.6, y: h * 0.9)); ctx.strokePath()
            ctx.setLineWidth(11); ctx.move(to: CGPoint(x: w * 0.4, y: 0)); ctx.addLine(to: CGPoint(x: w * 0.55, y: h)); ctx.strokePath()
            ctx.setFillColor(c(0xe4572e)); ctx.fillEllipse(in: CGRect(x: w * 0.46 - 16, y: h * 0.52 - 16, width: 32, height: 32))
        case "table":
            rect(ctx, CGRect(origin: .zero, size: s), c(0xffffff))
            titleBar(ctx, w)
            rect(ctx, CGRect(x: 0, y: 34, width: w, height: 40), c(0x2f7d5b))
            ctx.setStrokeColor(c(0xdddddd)); ctx.setLineWidth(1.2)
            var y: CGFloat = 74
            while y < h { ctx.move(to: CGPoint(x: 0, y: y)); ctx.addLine(to: CGPoint(x: w, y: y)); y += 36 }
            for k in 1..<6 { let x = w * CGFloat(k) / 6; ctx.move(to: CGPoint(x: x, y: 34)); ctx.addLine(to: CGPoint(x: x, y: h)) }
            ctx.strokePath()
            y = 86
            while y < h - 20 {
                for k in 0..<6 { rect(ctx, CGRect(x: w * CGFloat(k) / 6 + 12, y: y, width: (w / 6 - 24) * (0.4 + r.next() * 0.6), height: 10), c(0xb5b5b5), radius: 2) }
                y += 36
            }
        case "calendar":
            rect(ctx, CGRect(origin: .zero, size: s), c(0xffffff))
            titleBar(ctx, w)
            let cw = (w - 40) / 7, ch = (h - 80) / 5
            for row in 0..<5 { for col in 0..<7 {
                let cell = CGRect(x: 20 + CGFloat(col) * cw, y: 60 + CGFloat(row) * ch, width: cw - 4, height: ch - 4)
                rect(ctx, cell, c(0xf4f4f6), radius: 6)
                if r.next() > 0.7 { rect(ctx, CGRect(x: cell.minX + 6, y: cell.minY + 22, width: cell.width - 12, height: 12), c([0xf4a261, 0x2a9d8f, 0x8ab17d][Int(r.next() * 3)]), radius: 3) }
            } }
        default: // design
            rect(ctx, CGRect(origin: .zero, size: s), c(0xf2efe9))
            titleBar(ctx, w)
            rect(ctx, CGRect(x: w * 0.06, y: 60, width: w * 0.42, height: h * 0.58), c(0xd98e73), radius: 10)
            rect(ctx, CGRect(x: w * 0.54, y: 60, width: w * 0.4, height: h * 0.27), c(0x9db4a0), radius: 10)
            rect(ctx, CGRect(x: w * 0.54, y: 60 + h * 0.31, width: w * 0.4, height: h * 0.27), c(0xe9d8a6), radius: 10)
            rect(ctx, CGRect(x: w * 0.06, y: h * 0.82, width: w * 0.88, height: 22), c(0xbbbbbb), radius: 6)
        }
    }
}

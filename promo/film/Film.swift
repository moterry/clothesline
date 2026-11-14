import AppKit
import CoreGraphics
import Foundation

// MARK: - Script

struct ScriptLine: Decodable {
    let start: Double
    let zh: String
    let en: String
    let card: Bool?
}

struct FilmScript: Decodable {
    let duration: Double
    let lines: [ScriptLine]
}

// MARK: - Math

func clamp01(_ x: Double) -> Double { min(max(x, 0), 1) }
func prog(_ t: Double, _ a: Double, _ b: Double) -> Double { clamp01((t - a) / (b - a)) }
func smooth(_ x: Double) -> Double { x * x * (3 - 2 * x) }
func easeOut(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
func easeInOut(_ x: Double) -> Double { x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2 }
func lerp(_ a: CGFloat, _ b: CGFloat, _ t: Double) -> CGFloat { a + (b - a) * CGFloat(t) }
func lerp(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint { CGPoint(x: lerp(a.x, b.x, t), y: lerp(a.y, b.y, t)) }
func quad(_ a: CGPoint, _ c: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint { lerp(lerp(a, c, t), lerp(c, b, t), t) }

func col(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: a)
}
func nsc(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor { NSColor(cgColor: col(hex, a))! }

struct Rand {
    var s: UInt64
    init(_ seed: UInt64) { s = seed &* 0x9E37_79B9_7F4A_7C15 &+ 7 }
    mutating func next() -> CGFloat {
        s = s &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return CGFloat(s >> 11) / CGFloat(1 << 53)
    }
}

// MARK: - Fonts

enum Fonts {
    static func song(_ s: CGFloat) -> NSFont {
        NSFont(name: "STSongti-SC-Regular", size: s)
            ?? NSFontManager.shared.font(withFamily: "Songti SC", traits: [], weight: 5, size: s)
            ?? .systemFont(ofSize: s)
    }
    static func pal(_ s: CGFloat) -> NSFont { NSFont(name: "Palatino-Roman", size: s) ?? .systemFont(ofSize: s) }
    static func palItalic(_ s: CGFloat) -> NSFont { NSFont(name: "Palatino-Italic", size: s) ?? .systemFont(ofSize: s) }
    static func sys(_ s: CGFloat, _ w: NSFont.Weight = .regular) -> NSFont { .systemFont(ofSize: s, weight: w) }
}

// MARK: - Film

/// A 1920×1080 promo film for Clothesline, drawn frame by frame. `draw(t:)` is a pure function of time.
final class Film {
    let W: CGFloat = 1920, H: CGFloat = 1080
    let lang: String
    let script: FilmScript
    var zh: Bool { lang == "zh" }

    // Layout
    let menuH: CGFloat = 34
    let rope = RopeGeometry(width: 1920)
    let riverTop: CGFloat = 806, riverH: CGFloat = 180
    let bundleY: CGFloat = 888
    let bundleX0: CGFloat = 272, bundleStep: CGFloat = 222
    let subtitleY: CGFloat = 640
    let today = Day(year: 2026, month: 11, day: 14)

    // Content
    let shots: [CGImage]
    let ropeIdx = Array(0..<7)
    let ropeSlots: [Slot]
    let thumbIdx = 7          // the screenshot taken in scene 1
    let latecomerIdx = 8      // the screenshot dragged into Lethe in scene 5
    let latecomerSlot: Slot
    struct Bundle { let images: [CGImage]; let day: Day }
    let pastBundles: [Bundle]
    struct Icon { let pos: CGPoint; let img: CGImage; let l1: String; let l2: String; let appear: Double }
    let icons: [Icon]
    struct Glint { let x: CGFloat; let y: CGFloat; let len: CGFloat; let a: CGFloat }
    let glints: [Glint]

    init(lang: String, script: FilmScript) {
        self.lang = lang
        self.script = script
        let allShots = (0..<48).map { i in FakeShots.image(FakeShots.kinds[i % FakeShots.kinds.count], seed: UInt64(1000 + i * 37)) }
        shots = allShots

        func filmSize(_ img: CGImage) -> CGSize {
            let s = Thumb.fit(CGSize(width: img.width, height: img.height))
            return CGSize(width: s.width * 1.5, height: s.height * 1.5)
        }
        let g = rope
        let ropeImages = (0..<7).map { allShots[$0] }
        ropeSlots = g.layout(ropeImages.map(filmSize), names: ropeImages.indices.map { "rope-\($0)" })
        latecomerSlot = g.layout([filmSize(allShots[8])], names: ["late"])[0]

        let pastDays = [13, 12, 10, 8, 5, 1]
        pastBundles = pastDays.enumerated().map { k, d in
            Bundle(images: (0..<3).map { allShots[12 + k * 3 + $0] }, day: Day(year: 2026, month: 11, day: d))
        }

        var r = Rand(42)
        var list: [Icon] = []
        for i in 0..<46 {
            let pos: CGPoint
            if i < 26 {
                let c = CGFloat(i / 7), row = CGFloat(i % 7)
                pos = CGPoint(x: 1920 - 84 - c * 128 + (r.next() - 0.5) * 22, y: 104 + row * 122 + (r.next() - 0.5) * 18)
            } else {
                pos = CGPoint(x: 140 + r.next() * 1400, y: 110 + r.next() * 640)
            }
            let day = 14 - i / 5
            let hh = 9 + Int(r.next() * 10), mm = Int(r.next() * 60), ss = Int(r.next() * 60)
            let stamp = String(format: "%02d.%02d.%02d", hh, mm, ss)
            let date = String(format: "2026-11-%02d", max(day, 1))
            let appear = i == 0 ? 5.0 : 6.0 + 3.6 * pow(Double(i) / 45, 0.75)
            list.append(Icon(pos: pos, img: allShots[(i * 7 + 3) % 48],
                             l1: lang == "zh" ? "截屏 \(date)" : "Screenshot \(date)",
                             l2: lang == "zh" ? stamp : "at \(stamp)", appear: appear))
        }
        icons = list

        var gr = Rand(7)
        glints = (0..<46).map { _ in
            Glint(x: gr.next() * 1920, y: 806 + 16 + gr.next() * 148, len: 26 + gr.next() * 80, a: 0.15 + gr.next() * 0.35)
        }
    }

    // MARK: Frame

    func render(into ctx: CGContext, t: Double) {
        ctx.saveGState()
        ctx.translateBy(x: 0, y: H)
        ctx.scaleBy(x: 1, y: -1)
        ctx.interpolationQuality = .high
        ctx.setShouldAntialias(true)
        let ns = NSGraphicsContext(cgContext: ctx, flipped: true)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ns
        draw(ctx, t: t)
        NSGraphicsContext.restoreGraphicsState()
        ctx.restoreGState()
    }

    func draw(_ c: CGContext, t: Double) {
        wallpaper(c)
        vignette(c, t)
        desktopIcons(c, t)
        river(c, t)
        ropeLayer(c, t)
        lethe(c, t)
        titleS3(c, t)
        menuBar(c, t)
        dock(c)
        sceneOne(c, t)
        scissors(c, t)
        cursor(c, t)
        flash(c, t)
        endCard(c, t)
        subtitles(c, t)
    }

    // MARK: Primitives

    func fill(_ c: CGContext, _ r: CGRect, _ color: CGColor, radius: CGFloat = 0) {
        c.setFillColor(color)
        c.addPath(CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil))
        c.fillPath()
    }

    /// Draws a CGImage right side up in the y-down context.
    func image(_ c: CGContext, _ img: CGImage, _ r: CGRect) {
        c.saveGState()
        c.translateBy(x: r.minX, y: r.maxY)
        c.scaleBy(x: 1, y: -1)
        c.draw(img, in: CGRect(origin: .zero, size: r.size))
        c.restoreGState()
    }

    /// A framed screenshot: white border, soft shadow (or a glow), optional grey wash to look faded.
    func shot(_ c: CGContext, _ img: CGImage, _ r: CGRect, border: CGFloat = 4, alpha: CGFloat = 1,
              wash: CGFloat = 0, glow: CGFloat = 0) {
        c.saveGState()
        c.setAlpha(alpha)
        if glow > 0 {
            c.setShadow(offset: .zero, blur: 34, color: col(0xe8c77a, 0.9 * glow))
        } else {
            c.setShadow(offset: CGSize(width: 0, height: 4), blur: 9, color: col(0x000000, 0.22))
        }
        fill(c, r.insetBy(dx: -border, dy: -border), col(0xffffff))
        c.setShadow(offset: .zero, blur: 0, color: nil)
        image(c, img, r)
        if wash > 0 { fill(c, r, col(0xe4dfd6, wash)) }
        c.restoreGState()
    }

    func fitted(_ img: CGImage, in box: CGSize) -> CGSize {
        let k = min(box.width / CGFloat(img.width), box.height / CGFloat(img.height))
        return CGSize(width: CGFloat(img.width) * k, height: CGFloat(img.height) * k)
    }

    @discardableResult
    func text(_ s: String, _ font: NSFont, _ color: NSColor, at p: CGPoint, align: NSTextAlignment = .center,
              kern: CGFloat = 0, alpha: CGFloat = 1) -> CGSize {
        guard alpha > 0.001 else { return .zero }
        let a = NSAttributedString(string: s, attributes: [
            .font: font, .foregroundColor: color.withAlphaComponent(color.alphaComponent * alpha), .kern: kern,
        ])
        let size = a.size()
        var x = p.x
        if align == .center { x -= size.width / 2 } else if align == .right { x -= size.width }
        a.draw(at: CGPoint(x: x, y: p.y - size.height / 2))
        return size
    }

    func textSize(_ s: String, _ font: NSFont, kern: CGFloat = 0) -> CGSize {
        NSAttributedString(string: s, attributes: [.font: font, .kern: kern]).size()
    }

    // MARK: Desktop chrome

    func wallpaper(_ c: CGContext) {
        let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [col(0xefebe4), col(0xd8d2c7)] as CFArray, locations: [0, 1])!
        c.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: H), options: [])
    }

    func vignette(_ c: CGContext, _ t: Double) {
        let v = 0.16 * smooth(prog(t, 8.0, 10.5)) * (1 - smooth(prog(t, 11.0, 11.8)))
        guard v > 0 else { return }
        let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                           colors: [col(0x2a2620, 0), col(0x2a2620, CGFloat(v))] as CFArray, locations: [0.45, 1])!
        c.drawRadialGradient(g, startCenter: CGPoint(x: W / 2, y: H / 2), startRadius: 0,
                             endCenter: CGPoint(x: W / 2, y: H / 2), endRadius: W * 0.62, options: [.drawsAfterEndLocation])
    }

    func menuBar(_ c: CGContext, _ t: Double) {
        fill(c, CGRect(x: 0, y: 0, width: W, height: menuH), col(0xffffff, 0.42))
        c.setFillColor(col(0x2b2b2b, 0.85))
        c.fillEllipse(in: CGRect(x: 22, y: 11, width: 12, height: 12))
        for (i, w) in [58, 40, 40, 44, 46].enumerated() {
            fill(c, CGRect(x: 58 + CGFloat(i) * 70, y: 13, width: CGFloat(w), height: 8), col(0x2b2b2b, 0.28), radius: 4)
        }
        let clock = zh ? "11月14日 周六  10:42" : "Sat Nov 14  10:42"
        let size = text(clock, Fonts.sys(15, .medium), nsc(0x2b2b2b, 0.9), at: CGPoint(x: W - 22, y: menuH / 2), align: .right)
        // The Clothesline arc appears in the menu bar once the app is introduced.
        let a = CGFloat(smooth(prog(t, 11.9, 12.5)))
        if a > 0 {
            let x0 = W - 22 - size.width - 46
            c.saveGState()
            c.setStrokeColor(col(0x2b2b2b, 0.85 * a)); c.setLineWidth(1.8); c.setLineCap(.round)
            c.move(to: CGPoint(x: x0, y: 11)); c.addQuadCurve(to: CGPoint(x: x0 + 22, y: 11), control: CGPoint(x: x0 + 11, y: 25))
            c.strokePath()
            c.restoreGState()
        }
    }

    func dock(_ c: CGContext) {
        let w: CGFloat = 820, h: CGFloat = 74
        let r = CGRect(x: (W - w) / 2, y: H - h - 10, width: w, height: h)
        c.saveGState()
        c.setShadow(offset: CGSize(width: 0, height: 2), blur: 10, color: col(0x000000, 0.08))
        fill(c, r, col(0xffffff, 0.4), radius: 20)
        c.restoreGState()
        let palette: [UInt32] = [0x9db4c0, 0xe9c46a, 0xf4a261, 0x8ab17d, 0xb5838d, 0x6d6875, 0x83c5be, 0xe29578, 0xa3b18a, 0xcdb4db, 0x90a955, 0xbcb8b1]
        for (i, p) in palette.enumerated() {
            fill(c, CGRect(x: r.minX + 16 + CGFloat(i) * 66, y: r.minY + 10, width: 54, height: 54), col(p, 0.9), radius: 13)
        }
    }

    // MARK: Scene 1 — the floating thumbnail that slips away

    var thumbRect: CGRect {
        let s = fitted(shots[thumbIdx], in: CGSize(width: 300, height: 200))
        return CGRect(x: W - 40 - s.width, y: H - 40 - s.height, width: s.width, height: s.height)
    }

    func iconRect(_ icon: Icon) -> CGRect {
        let s = fitted(icon.img, in: CGSize(width: 84, height: 62))
        return CGRect(x: icon.pos.x - s.width / 2, y: icon.pos.y - s.height / 2, width: s.width, height: s.height)
    }

    func sceneOne(_ c: CGContext, _ t: Double) {
        guard t < 5.2 else { return }
        // Selection with a crosshair
        if t > 0.5 && t < 1.75 {
            let a = CGPoint(x: 760, y: 300), b = CGPoint(x: 1290, y: 610)
            let p = lerp(a, b, easeInOut(prog(t, 0.9, 1.65)))
            let sel = CGRect(x: a.x, y: a.y, width: p.x - a.x, height: p.y - a.y)
            if sel.width > 2 {
                fill(c, sel, col(0xffffff, 0.16))
                c.saveGState()
                c.setStrokeColor(col(0x3a3631, 0.55)); c.setLineWidth(1.2); c.setLineDash(phase: 0, lengths: [6, 4])
                c.stroke(sel); c.restoreGState()
                text("\(Int(sel.width)) × \(Int(sel.height))", Fonts.sys(13), nsc(0x3a3631, 0.7), at: CGPoint(x: p.x + 16, y: p.y + 22), align: .left)
            }
            c.saveGState()
            c.setStrokeColor(col(0x1a1a1a, 0.9)); c.setLineWidth(1.6)
            c.move(to: CGPoint(x: p.x - 14, y: p.y)); c.addLine(to: CGPoint(x: p.x + 14, y: p.y))
            c.move(to: CGPoint(x: p.x, y: p.y - 14)); c.addLine(to: CGPoint(x: p.x, y: p.y + 14)); c.strokePath()
            c.restoreGState()
        }
        // Floating thumbnail, its few seconds running out, then slipping onto the desktop
        if t > 1.9 {
            let r = thumbRect
            if t < 4.3 {
                let p = easeOut(prog(t, 1.9, 2.25))
                let rr = r.offsetBy(dx: lerp(90, 0, p), dy: 0)
                c.saveGState()
                c.setShadow(offset: CGSize(width: 0, height: 8), blur: 24, color: col(0x000000, 0.25))
                fill(c, rr.insetBy(dx: -6, dy: -6), col(0xffffff, CGFloat(p)), radius: 10)
                c.restoreGState()
                c.saveGState(); c.setAlpha(CGFloat(p)); image(c, shots[thumbIdx], rr); c.restoreGState()
                let left = 1 - prog(t, 2.25, 4.3)
                fill(c, CGRect(x: rr.minX, y: rr.maxY + 12, width: rr.width * CGFloat(left), height: 3), col(0x3a3631, 0.35 * CGFloat(p)), radius: 1.5)
            } else {
                let p = easeInOut(prog(t, 4.3, 5.0))
                let target = iconRect(icons[0])
                let center = quad(CGPoint(x: r.midX, y: r.midY), CGPoint(x: W - 120, y: 420), CGPoint(x: target.midX, y: target.midY), p)
                let w = lerp(r.width, target.width, p), h = lerp(r.height, target.height, p)
                shot(c, shots[thumbIdx], CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h), border: lerp(6, 3, p))
            }
        }
    }

    func flash(_ c: CGContext, _ t: Double) {
        guard t > 1.72 && t < 2.1 else { return }
        fill(c, CGRect(x: 0, y: 0, width: W, height: H), col(0xffffff, CGFloat(0.55 * (1 - prog(t, 1.72, 2.08)))))
    }

    // MARK: Scene 2 — the desktop fills up

    func desktopIcons(_ c: CGContext, _ t: Double) {
        guard t >= 5.0 && t < 12.0 else { return }
        let gone = prog(t, 11.0, 11.9)
        var r = Rand(99)
        for (i, icon) in icons.enumerated() {
            let drift = (r.next() - 0.5) * 120
            guard t >= icon.appear else { continue }
            let pop = i == 0 ? 1 : easeOut(prog(t, icon.appear, icon.appear + 0.2))
            let scale = CGFloat(0.6 + 0.4 * pop)
            let alpha = CGFloat(pop * (1 - smooth(gone)))
            guard alpha > 0.01 else { continue }
            let dy = CGFloat(-80 * easeOut(gone)), dx = drift * CGFloat(gone)
            let base = iconRect(icon)
            let rr = CGRect(x: icon.pos.x + dx - base.width * scale / 2, y: icon.pos.y + dy - base.height * scale / 2,
                            width: base.width * scale, height: base.height * scale)
            if hovered(icon, t) {
                fill(c, CGRect(x: icon.pos.x - 58, y: icon.pos.y - 42, width: 116, height: 128), col(0x000000, 0.09), radius: 8)
            }
            shot(c, icon.img, rr, border: 3, alpha: alpha)
            text(icon.l1, Fonts.sys(13, .medium), nsc(0x2b2b2b), at: CGPoint(x: icon.pos.x + dx, y: icon.pos.y + dy + 48), alpha: alpha)
            text(icon.l2, Fonts.sys(13, .medium), nsc(0x2b2b2b), at: CGPoint(x: icon.pos.x + dx, y: icon.pos.y + dy + 65), alpha: alpha)
        }
    }

    func hovered(_ icon: Icon, _ t: Double) -> Bool {
        guard t > 8.4 && t < 11.0, let p = cursorPoint(t) else { return false }
        return abs(p.x - icon.pos.x) < 50 && abs(p.y - icon.pos.y) < 50
    }

    // MARK: Scene 3 — the line

    func ropeLayer(_ c: CGContext, _ t: Double) {
        guard t >= 11.6 else { return }
        let p = easeInOut(prog(t, 11.6, 12.8))
        let x0 = rope.x0, x1 = rope.x0 + (rope.x1 - rope.x0) * CGFloat(p)
        c.saveGState()
        c.setStrokeColor(col(0x4a4540)); c.setLineWidth(1.6); c.setLineCap(.round)
        c.move(to: CGPoint(x: x0, y: rope.y(at: x0) + menuH))
        var x = x0
        while x < x1 { x = min(x + 12, x1); c.addLine(to: CGPoint(x: x, y: rope.y(at: x) + menuH)) }
        c.strokePath()
        c.restoreGState()
        text(Labels.today(today), Fonts.pal(18), nsc(0x7a7268), at: CGPoint(x: x0 + 4, y: menuH + 20), align: .left, kern: 4,
             alpha: CGFloat(smooth(prog(t, 12.4, 13.0))))

        let from = CGPoint(x: W - 190, y: H - 150)
        for (j, slot) in ropeSlots.enumerated() {
            let start = 12.7 + 0.38 * Double(j)
            guard t >= start else { continue }
            let arrive = easeInOut(prog(t, start, start + 0.95))
            let collapse = easeInOut(prog(t, 17.0 + Double(j) * 0.05, 18.4))
            if collapse >= 1 { continue }
            let pin = CGPoint(x: slot.pin.x, y: slot.pin.y + menuH)
            var center = quad(from, CGPoint(x: W - 420, y: 280), pin, arrive)
            var size = slot.size
            var tilt = slot.tiltDegrees * arrive
            var alpha = CGFloat(min(1, prog(t, start, start + 0.3)))
            var peg = arrive >= 1
            if collapse > 0 {
                let card = CGSize(width: 104, height: 69)
                let target = CGPoint(x: bundleX(0) + CGFloat(min(j, 2)) * 9, y: bundleY - 35 - CGFloat(min(j, 2)) * 7)
                center = quad(pin, CGPoint(x: pin.x - 120, y: 640), target, collapse)
                size = CGSize(width: lerp(slot.size.width, card.width, collapse), height: lerp(slot.size.height, card.height, collapse))
                tilt = slot.tiltDegrees * (1 - collapse)
                if j > 2 { alpha *= CGFloat(1 - collapse) }
                peg = collapse < 0.15
            }
            hang(c, shots[ropeIdx[j]], top: center, size: size, tilt: tilt, alpha: alpha, peg: peg)
        }

        // Scene 5: a latecomer arrives, is dragged to Lethe, and sinks.
        if t >= 22.5 && t < 26.2 {
            let slot = latecomerSlot
            let pin = CGPoint(x: slot.pin.x, y: slot.pin.y + menuH)
            if t < 23.5 {
                let a = easeInOut(prog(t, 22.5, 23.3))
                hang(c, shots[latecomerIdx], top: quad(from, CGPoint(x: W - 420, y: 280), pin, a), size: slot.size,
                     tilt: slot.tiltDegrees * a, alpha: CGFloat(min(1, prog(t, 22.5, 22.8))), peg: a >= 1)
            } else if t < 24.6 {
                let cp = cursorPoint(t) ?? pin
                let s = CGSize(width: slot.size.width * 0.9, height: slot.size.height * 0.9)
                shot(c, shots[latecomerIdx], CGRect(x: cp.x - s.width / 2, y: cp.y - 20, width: s.width, height: s.height), alpha: 0.92)
            } else {
                let p = prog(t, 24.6, 26.0)
                let s = CGSize(width: slot.size.width * 0.9, height: slot.size.height * 0.9)
                let center = CGPoint(x: letheCenter.x, y: letheCenter.y - 10 + CGFloat(55 * p))
                shot(c, shots[latecomerIdx], CGRect(x: center.x - s.width / 2, y: center.y - s.height / 2, width: s.width, height: s.height),
                     alpha: CGFloat(max(1 - p, 0)), wash: CGFloat(0.5 * p))
                c.saveGState()
                c.setStrokeColor(col(0x1d2633, CGFloat(0.45 * (1 - p)))); c.setLineWidth(1.2)
                let rw = 70 + 190 * CGFloat(p), rh = 14 + 30 * CGFloat(p)
                c.strokeEllipse(in: CGRect(x: letheCenter.x - rw / 2, y: letheCenter.y + 30 + CGFloat(40 * p) - rh / 2, width: rw, height: rh))
                c.restoreGState()
            }
        }
    }

    /// A screenshot hanging from its peg at `top` (the peg point), rotated around it.
    func hang(_ c: CGContext, _ img: CGImage, top: CGPoint, size: CGSize, tilt: Double, alpha: CGFloat, peg: Bool) {
        c.saveGState()
        c.translateBy(x: top.x, y: top.y)
        c.rotate(by: CGFloat(tilt * .pi / 180))
        shot(c, img, CGRect(x: -size.width / 2, y: 11, width: size.width, height: size.height), alpha: alpha)
        if peg { fill(c, CGRect(x: -4, y: -9, width: 8, height: 23), col(0x9a7b4f, alpha), radius: 2) }
        c.restoreGState()
    }

    func titleS3(_ c: CGContext, _ t: Double) {
        let a = CGFloat(smooth(prog(t, 12.0, 12.7)) * (1 - smooth(prog(t, 15.9, 16.5))))
        guard a > 0 else { return }
        if zh {
            text("晾衣绳", Fonts.song(124), nsc(0x3d3934), at: CGPoint(x: W / 2, y: 430), kern: 30, alpha: a)
            text("CLOTHESLINE", Fonts.pal(24), nsc(0x7a7268), at: CGPoint(x: W / 2, y: 520), kern: 12, alpha: a)
        } else {
            text("Clothesline", Fonts.pal(112), nsc(0x3d3934), at: CGPoint(x: W / 2, y: 430), kern: 6, alpha: a)
            text("晾 衣 绳", Fonts.song(28), nsc(0x7a7268), at: CGPoint(x: W / 2, y: 520), kern: 14, alpha: a)
        }
    }

    // MARK: Scene 4 — the cut, the river, recollection

    func bundleX(_ slot: CGFloat) -> CGFloat { bundleX0 + slot * bundleStep }

    func scissors(_ c: CGContext, _ t: Double) {
        guard t > 16.4 && t < 17.5 else { return }
        let a = CGFloat(smooth(prog(t, 16.4, 16.7)) * (1 - smooth(prog(t, 17.15, 17.45))))
        let x: CGFloat = 1560, y = rope.y(at: 1560) + menuH
        let open = CGFloat(28 - 24 * easeInOut(prog(t, 16.75, 16.98))) * .pi / 180
        c.saveGState()
        c.translateBy(x: x, y: y)
        c.setStrokeColor(col(0x3d3934, a)); c.setLineWidth(2.2); c.setLineCap(.round)
        for s in [-1.0, 1.0] {
            c.saveGState()
            c.rotate(by: open * CGFloat(s) + .pi / 2)
            c.move(to: CGPoint(x: -26, y: 0)); c.addLine(to: CGPoint(x: 30, y: 0)); c.strokePath()
            c.strokeEllipse(in: CGRect(x: -44, y: -9, width: 18, height: 18))
            c.restoreGState()
        }
        c.restoreGState()
    }

    var letheCenter: CGPoint { CGPoint(x: W - 120, y: bundleY + 6) }

    func river(_ c: CGContext, _ t: Double) {
        let ra = CGFloat(smooth(prog(t, 13.4, 14.4)))
        guard ra > 0 && t < 26.9 else { return }
        let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                           colors: [col(0x4f6f8f, 0), col(0x4f6f8f, 0.17 * ra), col(0x4f6f8f, 0)] as CFArray, locations: [0, 0.5, 1])!
        c.drawLinearGradient(g, start: CGPoint(x: 0, y: riverTop), end: CGPoint(x: 0, y: riverTop + riverH), options: [])
        c.saveGState()
        c.setLineWidth(1.1)
        for gl in glints {
            var x = (gl.x - CGFloat(t) * 9).truncatingRemainder(dividingBy: W + 120)
            if x < -120 { x += W + 120 }
            c.setStrokeColor(col(0xffffff, gl.a * ra))
            c.move(to: CGPoint(x: x, y: gl.y)); c.addLine(to: CGPoint(x: x + gl.len, y: gl.y)); c.strokePath()
        }
        c.restoreGState()
        text("ΜΝΗΜΟΣΥΝΗ", Fonts.pal(15), nsc(0x8a7650), at: CGPoint(x: 52, y: riverTop + 2), align: .left, kern: 6, alpha: 0.9 * ra)
        text("ΛΗΘΗ →", Fonts.pal(15), nsc(0x8a7650), at: CGPoint(x: W - 52, y: riverTop + 2), align: .right, kern: 6, alpha: 0.55 * ra)

        let shift = CGFloat(easeInOut(prog(t, 17.4, 18.4)))
        let hover = smooth(prog(t, 19.7, 20.1)) * (1 - smooth(prog(t, 22.3, 22.7)))
        for (k, b) in pastBundles.enumerated() {
            let age = today.day - b.day.day
            drawBundle(c, b.images, label: Labels.bundle(BundleID(day: b.day, ordinal: 1), dayHasSeveral: false, currentYear: 2026),
                       x: bundleX(CGFloat(k) + shift), age: age, alpha: ra, hover: k == 1 ? hover : 0)
        }
        if t >= 18.4 {
            drawBundle(c, ropeIdx.prefix(3).map { shots[$0] }, label: Labels.bundle(BundleID(day: today, ordinal: 1), dayHasSeveral: false, currentYear: 2026),
                       x: bundleX(0), age: 0, alpha: ra, hover: 0, labelAlpha: CGFloat(smooth(prog(t, 18.4, 18.9))))
        }
        if hover > 0 {
            let cap = zh ? "ἀνάμνησις · 回忆" : "ἀνάμνησις · recollection"
            text(cap, Fonts.palItalic(27), nsc(0x9a7b3c), at: CGPoint(x: bundleX(2) + 8, y: bundleY - 158), alpha: CGFloat(hover))
        }
    }

    func drawBundle(_ c: CGContext, _ imgs: [CGImage], label: String, x: CGFloat, age: Int, alpha: CGFloat, hover: Double,
                    labelAlpha: CGFloat = 1) {
        let f = Fade.appearance(age: age)
        let h = CGFloat(hover)
        let opacity = lerp(CGFloat(f.opacity), 1, hover) * alpha
        let wash = (1 - CGFloat(f.saturation)) * 0.6 * (1 - h)
        let scale = 1 + 0.28 * h
        let card = CGSize(width: 104 * scale, height: 69 * scale)
        let lift = -30 * h
        for j in stride(from: min(imgs.count, 3) - 1, through: 0, by: -1) {
            c.saveGState()
            let cx = x + CGFloat(j) * 9 * scale, cy = bundleY - 35 * scale + lift - CGFloat(j) * 7 * scale
            c.translateBy(x: cx, y: cy)
            c.rotate(by: CGFloat(j - 1) * 2 * .pi / 180)
            shot(c, imgs[j], CGRect(x: -card.width / 2, y: -card.height / 2, width: card.width, height: card.height),
                 border: 3, alpha: opacity, wash: wash, glow: j == 0 ? h : 0)
            c.restoreGState()
        }
        text(label, Fonts.pal(17), nsc(h > 0.5 ? 0x9a7b3c : 0x8a7650), at: CGPoint(x: x + 6, y: bundleY + 30 + lift * 0.3),
             kern: 3, alpha: opacity * labelAlpha)
    }

    // MARK: Scene 5 — Lethe

    func lethe(_ c: CGContext, _ t: Double) {
        let a = CGFloat(smooth(prog(t, 23.4, 23.8)) * (1 - smooth(prog(t, 25.7, 26.3))))
        guard a > 0 else { return }
        let target = CGFloat(smooth(prog(t, 24.1, 24.5)) * (1 - smooth(prog(t, 24.7, 25.2))))
        let s = 1 + 0.08 * target
        let w = 230 * s, h = 150 * s
        let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                           colors: [col(0x1d2633, (0.62 + 0.15 * target) * a), col(0x1d2633, 0)] as CFArray, locations: [0, 1])!
        c.saveGState()
        c.translateBy(x: letheCenter.x, y: letheCenter.y)
        c.scaleBy(x: 1, y: h / w)
        c.drawRadialGradient(g, startCenter: .zero, startRadius: 4, endCenter: .zero, endRadius: w / 2, options: [])
        c.restoreGState()
        c.saveGState()
        c.setStrokeColor(col(0x1d2633, 0.3 * a)); c.setLineWidth(1)
        c.strokeEllipse(in: CGRect(x: letheCenter.x - w / 2 + 26, y: letheCenter.y - h / 2 + 22, width: w - 52, height: h - 44))
        c.restoreGState()
        text("ΛΗΘΗ", Fonts.pal(18), nsc(0xffffff), at: letheCenter, kern: 7, alpha: 0.88 * a)
    }

    // MARK: Cursor

    func cursorPoint(_ t: Double) -> CGPoint? {
        func path(_ pts: [CGPoint], _ a: Double, _ b: Double) -> CGPoint {
            let x = prog(t, a, b) * Double(pts.count - 1)
            let i = min(Int(x), pts.count - 2)
            return lerp(pts[i], pts[i + 1], easeInOut(x - Double(i)))
        }
        if t >= 8.2 && t < 11.0 {
            return path([CGPoint(x: 1180, y: 560), CGPoint(x: 1660, y: 236), CGPoint(x: 1410, y: 470),
                         CGPoint(x: 1790, y: 590), CGPoint(x: 1290, y: 300), CGPoint(x: 1540, y: 712)], 8.2, 10.9)
        }
        let bundle = CGPoint(x: bundleX(2) + 8, y: bundleY - 22)
        let pin = CGPoint(x: latecomerSlot.pin.x + 6, y: latecomerSlot.pin.y + menuH + latecomerSlot.size.height * 0.55)
        if t >= 18.5 && t < 22.6 { return path([CGPoint(x: 1500, y: 640), bundle], 18.6, 19.8) }
        if t >= 22.6 && t < 23.5 { return path([bundle, pin], 22.7, 23.45) }
        if t >= 23.5 && t < 24.6 { return quad(pin, CGPoint(x: 1300, y: 520), CGPoint(x: letheCenter.x, y: letheCenter.y - 6), easeInOut(prog(t, 23.5, 24.55))) }
        if t >= 24.6 && t < 26.0 { return lerp(CGPoint(x: letheCenter.x, y: letheCenter.y - 6), CGPoint(x: letheCenter.x - 160, y: letheCenter.y - 130), easeInOut(prog(t, 25.0, 25.9))) }
        return nil
    }

    func cursor(_ c: CGContext, _ t: Double) {
        guard let p = cursorPoint(t) else { return }
        let a: CGFloat
        if t < 11.0 { a = CGFloat(smooth(prog(t, 8.2, 8.5)) * (1 - smooth(prog(t, 10.6, 10.95)))) }
        else if t < 22.6 { a = CGFloat(smooth(prog(t, 18.5, 18.8))) }
        else { a = CGFloat(1 - smooth(prog(t, 25.5, 25.95))) }
        guard a > 0 else { return }
        let pts: [CGPoint] = [(0, 0), (0, 26), (6, 20), (11, 31), (15, 29), (10, 19), (18, 19)].map { CGPoint(x: $0.0 * 1.4, y: $0.1 * 1.4) }
        c.saveGState()
        c.translateBy(x: p.x, y: p.y)
        c.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: col(0x000000, 0.3 * a))
        c.addLines(between: pts); c.closePath()
        c.setFillColor(col(0x111111, a)); c.fillPath()
        c.setShadow(offset: .zero, blur: 0, color: nil)
        c.addLines(between: pts); c.closePath()
        c.setStrokeColor(col(0xffffff, a)); c.setLineWidth(1.6); c.strokePath()
        c.restoreGState()
    }

    // MARK: Scene 6 — end card

    func endCard(_ c: CGContext, _ t: Double) {
        let k = CGFloat(smooth(prog(t, 26.0, 26.8)))
        guard k > 0 else { return }
        fill(c, CGRect(x: 0, y: 0, width: W, height: H), col(0xf4f0e8, k))
        let m = easeInOut(prog(t, 26.4, 27.2))
        if m > 0 {
            let a = CGPoint(x: W / 2 - 240, y: 318), b = CGPoint(x: W / 2 + 240, y: 318), ctl = CGPoint(x: W / 2, y: 398)
            c.saveGState()
            c.setStrokeColor(col(0x4a4540)); c.setLineWidth(1.6); c.setLineCap(.round)
            c.move(to: a)
            var s = 0.0
            while s < m { s = min(s + 0.02, m); c.addLine(to: quad(a, ctl, b, s)) }
            c.strokePath()
            c.restoreGState()
            for p in [0.3, 0.5, 0.7] where m >= p {
                let q = quad(a, ctl, b, p)
                let pop = CGFloat(easeOut(prog(t, 26.4 + p * 0.8, 26.6 + p * 0.8)))
                fill(c, CGRect(x: q.x - 4, y: q.y - 9 * pop, width: 8, height: 22 * pop), col(0x9a7b4f), radius: 2)
            }
        }
        let ta = CGFloat(smooth(prog(t, 26.8, 27.4)))
        if zh {
            text("晾衣绳", Fonts.song(108), nsc(0x3d3934), at: CGPoint(x: W / 2, y: 478), kern: 26, alpha: ta)
            text("CLOTHESLINE", Fonts.pal(24), nsc(0x7a7268), at: CGPoint(x: W / 2, y: 560), kern: 12, alpha: ta)
        } else {
            text("Clothesline", Fonts.pal(100), nsc(0x3d3934), at: CGPoint(x: W / 2, y: 478), kern: 5, alpha: ta)
            text("晾 衣 绳", Fonts.song(28), nsc(0x7a7268), at: CGPoint(x: W / 2, y: 560), kern: 14, alpha: ta)
        }
        let la = CGFloat(smooth(prog(t, 27.3, 27.9)))
        if zh {
            text("绳是现在 · 河是过去 · 忘川是放下", Fonts.song(36), nsc(0x4a4540), at: CGPoint(x: W / 2, y: 664), kern: 4, alpha: la)
        } else {
            text("The line is now · The river is the past · Lethe is letting go", Fonts.palItalic(34), nsc(0x4a4540), at: CGPoint(x: W / 2, y: 664), alpha: la)
        }
        text("github.com/moterry/clothesline", Fonts.sys(22), nsc(0x7a7268), at: CGPoint(x: W / 2, y: 950), kern: 1,
             alpha: CGFloat(smooth(prog(t, 28.4, 29.0))))
    }

    // MARK: Subtitles

    func subtitles(_ c: CGContext, _ t: Double) {
        let lines = script.lines
        for (i, line) in lines.enumerated() where line.card != true {
            let end = (i + 1 < lines.count ? lines[i + 1].start : script.duration) - 0.25
            guard t >= line.start && t <= end else { continue }
            let a = CGFloat(smooth(prog(t, line.start, line.start + 0.3)) * (1 - smooth(prog(t, end - 0.3, end))))
            let s = zh ? line.zh : line.en
            let font = zh ? Fonts.song(38) : Fonts.palItalic(36)
            let size = textSize(s, font, kern: zh ? 2 : 0)
            fill(c, CGRect(x: W / 2 - size.width / 2 - 30, y: subtitleY - size.height / 2 - 12, width: size.width + 60, height: size.height + 24),
                 col(0xf4f0e8, 0.8 * a), radius: (size.height + 24) / 2)
            text(s, font, nsc(0x3d3934), at: CGPoint(x: W / 2, y: subtitleY), kern: zh ? 2 : 0, alpha: a)
        }
    }
}

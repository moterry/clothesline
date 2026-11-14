import CoreGraphics
import Foundation

/// Where one screenshot hangs: the peg point on the curve, the thumbnail size, and its tilt.
struct Slot: Equatable {
    let pin: CGPoint
    let size: CGSize
    let tiltDegrees: Double
}

/// The hanging line, in the top strip's local coordinates (y grows downward).
/// Values come from the 1440-wide sketch and scale linearly with the strip width.
struct RopeGeometry {
    let width: CGFloat
    let scale: CGFloat
    let x0: CGFloat
    let x1: CGFloat
    let y0: CGFloat
    let sag: CGFloat
    let firstSlotX: CGFloat
    let gap: CGFloat

    init(width: CGFloat) {
        self.width = width
        scale = width / 1440
        x0 = 50 * scale
        x1 = width - 50 * scale
        y0 = 38 * scale
        sag = 80 * scale
        firstSlotX = x0 + 80 * scale
        gap = 22 * scale
    }

    private func t(_ x: CGFloat) -> CGFloat { (x - x0) / (x1 - x0) }

    /// y = y0 + 4·sag·t·(1−t): a quadratic approximation of a catenary.
    func y(at x: CGFloat) -> CGFloat {
        let t = t(x)
        return y0 + 4 * sag * t * (1 - t)
    }

    func slope(at x: CGFloat) -> CGFloat {
        4 * sag * (1 - 2 * t(x)) / (x1 - x0)
    }

    func path() -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: x0, y: y0))
        p.addQuadCurve(to: CGPoint(x: x1, y: y0), control: CGPoint(x: (x0 + x1) / 2, y: y0 + 2 * sag))
        return p
    }

    /// Lays thumbnails left to right from `firstSlotX`, `gap` apart; shrinks them uniformly if they would not fit.
    func layout(_ sizes: [CGSize], names: [String]) -> [Slot] {
        guard !sizes.isEmpty else { return [] }
        let gaps = gap * CGFloat(sizes.count - 1)
        let total = sizes.reduce(0) { $0 + $1.width }
        let available = x1 - 20 * scale - firstSlotX
        let k = total + gaps > available ? max((available - gaps) / total, 0.1) : 1
        var cursor = firstSlotX
        return zip(sizes, names).map { size, name in
            let s = CGSize(width: size.width * k, height: size.height * k)
            let cx = cursor + s.width / 2
            cursor += s.width + gap
            let tilt = atan(Double(slope(at: cx))) * 180 / .pi * 0.35 + Tilt.jitter(for: name)
            return Slot(pin: CGPoint(x: cx, y: y(at: cx)), size: s, tiltDegrees: tilt)
        }
    }
}

enum Thumb {
    static let maxSize = CGSize(width: 105, height: 84)

    /// Largest size within `maxSize` keeping the aspect ratio. Unknown sizes get a 3:2 default.
    static func fit(_ pixels: CGSize) -> CGSize {
        guard pixels.width > 0, pixels.height > 0 else { return CGSize(width: maxSize.width, height: (maxSize.width * 2 / 3).rounded()) }
        let k = min(maxSize.width / pixels.width, maxSize.height / pixels.height)
        return CGSize(width: (pixels.width * k).rounded(), height: (pixels.height * k).rounded())
    }
}

enum Tilt {
    /// A stable per-name angle in −1.5…1.5 degrees (FNV-1a hash), so each screenshot looks hand-hung but never jitters.
    static func jitter(for name: String) -> Double {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in name.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return Double(hash % 3001) / 1000 - 1.5
    }
}

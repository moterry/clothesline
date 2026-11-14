import AppKit
import SwiftUI

/// Visual constants from the design (light palette, v1).
enum Theme {
    static let line = Color(hex: 0x4a4540)
    static let lineWidth: CGFloat = 1.1
    static let peg = Color(hex: 0x9a7b4f)
    static let pegSize = CGSize(width: 6, height: 17)
    static let frame: CGFloat = 3
    static let ink = Color(hex: 0x7a7268)
    static let water = Color(hex: 0x4f6f8f)
    static let waterOpacity = 0.16
    static let riverText = Color(hex: 0x8a7650)
    static let riverTextHover = Color(hex: 0x9a7b3c)
    static let glow = Color(hex: 0xe8c77a)
    static let lethe = Color(hex: 0x1d2633)

    static let riverHeight: CGFloat = 130
    static let topStripHeight: CGFloat = 420
    static let bottomStripHeight: CGFloat = 170
    static let bottomStripExpandedHeight: CGFloat = 380

    /// Inscriptional capitals (Palatino covers Latin + polytonic Greek).
    static func inscription(_ size: CGFloat) -> Font { .custom("Palatino-Roman", size: size) }
    static let inscriptionTracking: CGFloat = 3
    static func song(_ size: CGFloat) -> Font { .custom("Songti SC", size: size) }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255,
                  opacity: opacity)
    }
}

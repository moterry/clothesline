import Foundation

/// Older bundles grow fainter and greyer, reaching a floor at 30 days so content stays recognisable.
enum Fade {
    static let floorDays = 30
    static let minOpacity = 0.45
    static let minSaturation = 0.15

    static func appearance(age days: Int) -> (opacity: Double, saturation: Double) {
        if days >= floorDays { return (minOpacity, minSaturation) }
        let t = Double(max(days, 0)) / Double(floorDays)
        return (1 - t * (1 - minOpacity), 1 - t * (1 - minSaturation))
    }
}

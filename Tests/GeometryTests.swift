import CoreGraphics
import Foundation
import Testing

@Test func curveEndsAndMiddle() {
    let g = RopeGeometry(width: 1440)
    #expect(g.x0 == 50)
    #expect(g.x1 == 1390)
    #expect(g.y(at: g.x0) == 38)
    #expect(g.y(at: g.x1) == 38)
    #expect(g.y(at: 720) == 118)
    #expect(g.slope(at: 720) == 0)
}

@Test func curveScalesWithWidth() {
    let g = RopeGeometry(width: 2880)
    #expect(g.x0 == 100)
    #expect(g.sag == 160)
}

@Test func fitKeepsAspect() {
    // 30% smaller than the original 150×120 cap, at the user's request (hands-on session).
    #expect(Thumb.maxSize == CGSize(width: 105, height: 84))
    #expect(Thumb.fit(CGSize(width: 3000, height: 2000)) == CGSize(width: 105, height: 70))
    #expect(Thumb.fit(CGSize(width: 1000, height: 2000)) == CGSize(width: 42, height: 84))
    #expect(Thumb.fit(CGSize(width: 0, height: 0)) == CGSize(width: 105, height: 70))
}

@Test func slotsFollowCurveLeftToRight() {
    let g = RopeGeometry(width: 1440)
    let slots = g.layout([CGSize(width: 100, height: 80), CGSize(width: 60, height: 120)], names: ["a", "b"])
    #expect(slots.count == 2)
    #expect(slots[0].pin.x == CGFloat(180))
    #expect(slots[1].pin.x == CGFloat(282))
    #expect(slots.allSatisfy { abs($0.pin.y - g.y(at: $0.pin.x)) < 0.001 })
    #expect(slots[0].size == CGSize(width: 100, height: 80))
}

@Test func twelveWideShotsFitOnScreen() {
    let g = RopeGeometry(width: 1440)
    let slots = g.layout(Array(repeating: CGSize(width: 150, height: 100), count: 12), names: (0..<12).map { "\($0)" })
    #expect(slots.count == 12)
    #expect(slots.last!.pin.x + slots.last!.size.width / 2 <= g.x1)
    #expect(slots.allSatisfy { abs($0.pin.y - g.y(at: $0.pin.x)) < 0.001 })
    #expect(abs(slots[0].size.width / slots[0].size.height - 1.5) < 0.001)
}

@Test func tiltFollowsSlopePlusJitter() {
    let g = RopeGeometry(width: 1440)
    let slot = g.layout([CGSize(width: 100, height: 80)], names: ["a.png"])[0]
    let expected = atan(Double(g.slope(at: slot.pin.x))) * 180 / .pi * 0.35 + Tilt.jitter(for: "a.png")
    #expect(abs(slot.tiltDegrees - expected) < 1e-9)
}

@Test func jitterStableAndBounded() {
    #expect(Tilt.jitter(for: "a.png") == Tilt.jitter(for: "a.png"))
    #expect(Tilt.jitter(for: "a.png") != Tilt.jitter(for: "b.png"))
    for name in ["截屏 1.png", "x", "", "Screenshot 2026-11-14 at 10.00.00.png"] {
        #expect((-1.5...1.5).contains(Tilt.jitter(for: name)))
    }
}

@Test func fadeCurve() {
    #expect(Fade.appearance(age: 0) == (1, 1))
    #expect(Fade.appearance(age: 30) == (0.45, 0.15))
    #expect(Fade.appearance(age: 400) == (0.45, 0.15))
    #expect(Fade.appearance(age: -2) == (1, 1))
    let m = Fade.appearance(age: 15)
    #expect(abs(m.opacity - 0.725) < 1e-9 && abs(m.saturation - 0.575) < 1e-9)
}

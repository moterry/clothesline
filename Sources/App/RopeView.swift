import SwiftUI

/// The top strip: today's inscription, the hanging line, and the screenshots pegged to it.
struct RopeView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        GeometryReader { proxy in
            let g = RopeGeometry(width: proxy.size.width)
            let shots = model.snapshot.rope
            let sizes = shots.map { Thumb.fit(ThumbnailCache.shared.pixelSize($0.url)) }
            let slots = g.layout(sizes, names: shots.map(\.url.lastPathComponent))

            ZStack(alignment: .topLeading) {
                Text(Labels.today(model.today()))
                    .font(Theme.inscription(12 * g.scale))
                    .tracking(Theme.inscriptionTracking)
                    .foregroundStyle(Theme.ink)
                    .position(x: g.x0 + 60 * g.scale, y: 16 * g.scale)
                    .fixedSize()

                Path(g.path())
                    .stroke(Theme.line, style: StrokeStyle(lineWidth: Theme.lineWidth, lineCap: .round))
                    .allowsHitTesting(false)

                ForEach(Array(zip(shots, slots)), id: \.0.id) { shot, slot in
                    HangingShot(model: model, shot: shot, slot: slot, siblings: shots.map(\.url),
                                arrivingFrom: CGPoint(x: proxy.size.width - 90, y: proxy.size.height + 200))
                        .transition(.asymmetric(insertion: .identity,
                                                removal: .offset(x: -180, y: 260).combined(with: .opacity)))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
    }
}

/// A screenshot hanging from its peg; floats in from the bottom-right when it has just arrived.
private struct HangingShot: View {
    @ObservedObject var model: AppModel
    let shot: Shot
    let slot: Slot
    let siblings: [URL]
    let arrivingFrom: CGPoint

    @State private var landed = false

    var body: some View {
        let arriving = model.arriving.contains(shot.url) && !landed
        VStack(spacing: 0) {
            ShotCard(shot: shot, size: slot.size)
                .shotInteractions(model: model, shot: shot, size: slot.size, siblings: siblings)
                .padding(.top, 7)
        }
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Theme.peg)
                .frame(width: Theme.pegSize.width, height: Theme.pegSize.height)
                .offset(y: -7)
        }
        .rotationEffect(.degrees(slot.tiltDegrees), anchor: .top)
        .position(x: arriving ? arrivingFrom.x : slot.pin.x,
                  y: arriving ? arrivingFrom.y : slot.pin.y + (slot.size.height + 7 + 2 * Theme.frame) / 2)
        .opacity(arriving ? 0 : 1)
        .zIndex(model.hovered == shot.url ? 10 : 0)
        .onAppear {
            guard model.arriving.contains(shot.url) else { landed = true; return }
            withAnimation(.easeInOut(duration: 1.0)) { landed = true }
        }
    }
}

import SwiftUI
import UniformTypeIdentifiers

/// A dark pool at the river's downstream end. It surfaces while a screenshot is being dragged, and stays
/// while anything is sinking: whatever is dropped here (or sent by the menu) sinks *here*, in the pool,
/// and a click on it within the five seconds brings it back to where it came from.
struct LetheZone: View {
    @ObservedObject var model: AppModel
    @State private var targeted = false

    var body: some View {
        let groups = model.lethe.sinking
        let active = model.isDragging || !groups.isEmpty
        ZStack {
            pool
                .scaleEffect(targeted ? 1.08 : 1)
                .allowsHitTesting(model.isDragging)
                .onDrop(of: [UTType.fileURL, UTType.item], isTargeted: $targeted) { _ in
                    // Sink what our own drag carries; a stray drop from Finder (no drag of ours) is refused.
                    model.dropOnLethe()
                }

            ForEach(Array(groups.enumerated()), id: \.element.id) { i, group in
                SinkingCard(model: model, urls: group.urls, progress: model.lethe.progress(group.id, now: model.now))
                    .offset(x: CGFloat(i) * 26 - CGFloat(groups.count - 1) * 13)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
            .allowsHitTesting(!model.isDragging)

            if !groups.isEmpty && !model.isDragging {
                Text("单击捞回")
                    .font(Theme.song(10))
                    .tracking(2)
                    .foregroundStyle(Color.white.opacity(0.75))
                    .offset(y: 30)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .frame(width: 160, height: 110)
        .opacity(active ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: active)
        .animation(.easeOut(duration: 0.2), value: targeted)
        .animation(.easeOut(duration: 0.25), value: groups.map(\.id))
    }

    private var pool: some View {
        ZStack {
            Ellipse()
                .fill(RadialGradient(colors: [Theme.lethe.opacity(targeted ? 0.75 : 0.55), Theme.lethe.opacity(0)],
                                     center: .center, startRadius: 4, endRadius: 80))
            Ellipse()
                .stroke(Theme.lethe.opacity(targeted ? 0.5 : 0.3), lineWidth: 0.8)
                .padding(18)
            Text("ΛΗΘΗ")
                .font(Theme.inscription(13))
                .tracking(5)
                .foregroundStyle(Color.white.opacity(targeted ? 0.9 : 0.7))
        }
    }
}

/// One sinking screenshot (or a bundle's top three, stacked askew), going down into the pool over the
/// five seconds: it drops, shrinks and fades while a ripple widens on the surface. A click rescues it.
private struct SinkingCard: View {
    @ObservedObject var model: AppModel
    let urls: [URL]
    let progress: Double

    var body: some View {
        let p = progress
        ZStack {
            ForEach(Array(urls.prefix(3).enumerated().reversed()), id: \.element) { j, url in
                ShotCard(shot: Shot(url: url, created: .distantPast), size: Self.size(url))
                    .rotationEffect(.degrees(Double(j - 1) * 2))
                    .offset(x: CGFloat(j) * 5, y: CGFloat(j) * -4)
            }
        }
        .scaleEffect(1 - 0.4 * p)
        .offset(y: -12 + 30 * p)
        .opacity(max(1 - 1.15 * p, 0))
        .overlay {
            Ellipse()
                .stroke(Color.white.opacity(0.45 * (1 - p)), lineWidth: 0.8)
                .frame(width: 36 + 100 * p, height: 8 + 16 * p)
                .offset(y: 14)
                .allowsHitTesting(false)
        }
        .animation(.linear(duration: 0.25), value: p)
        .contentShape(Rectangle())
        .onTapGesture { model.rescue(urls) }
        .help("单击捞回")
    }

    /// Small enough to sit inside the pool: about half a hanging thumbnail.
    static func size(_ url: URL) -> CGSize {
        let s = Thumb.fit(ThumbnailCache.shared.pixelSize(url))
        return CGSize(width: (s.width * 0.55).rounded(), height: (s.height * 0.55).rounded())
    }
}

/// Where a screenshot (or a whole bundle) used to be while it sinks in Lethe: an empty space, so the
/// sinking happens only in the pool. Rescued, it reappears in place.
struct Sinking: ViewModifier {
    @ObservedObject var model: AppModel
    let urls: [URL]

    func body(content: Content) -> some View {
        let gone = !urls.isEmpty && urls.allSatisfy { model.isSinking($0) }
        content
            .opacity(gone ? 0 : 1)
            .allowsHitTesting(!gone)
            .animation(.easeOut(duration: 0.2), value: gone)
    }
}

extension View {
    func sinking(model: AppModel, urls: [URL]) -> some View {
        modifier(Sinking(model: model, urls: urls))
    }
}

import SwiftUI
import UniformTypeIdentifiers

/// A dark pool at the river's downstream end. It surfaces only while a screenshot is being dragged;
/// whatever is dropped here sinks into Lethe.
struct LetheZone: View {
    @ObservedObject var model: AppModel
    @State private var targeted = false

    var body: some View {
        ZStack {
            Ellipse()
                .fill(RadialGradient(colors: [Theme.lethe.opacity(targeted ? 0.55 : 0.4), Theme.lethe.opacity(0)],
                                     center: .center, startRadius: 4, endRadius: 80))
            Ellipse()
                .stroke(Theme.lethe.opacity(targeted ? 0.35 : 0.15), lineWidth: 0.8)
                .padding(18)
            Text("ΛΗΘΗ")
                .font(Theme.inscription(13))
                .tracking(5)
                .foregroundStyle(Color.white.opacity(targeted ? 0.9 : 0.7))
        }
        .frame(width: 160, height: 110)
        .scaleEffect(targeted ? 1.08 : 1)
        .opacity(model.isDragging ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: model.isDragging)
        .animation(.easeOut(duration: 0.2), value: targeted)
        .allowsHitTesting(model.isDragging)
        .onDrop(of: [UTType.fileURL], isTargeted: $targeted) { providers in
            // Only our own drags (visible pool) may sink anything; a stray Finder drop is refused.
            guard model.isDragging else { return false }
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    DispatchQueue.main.async { model.sink([url]) }
                }
            }
            return true
        }
    }
}

/// Sinking visuals: the screenshot drifts down and fades over the five seconds, with a widening ripple.
struct Sinking: ViewModifier {
    @ObservedObject var model: AppModel
    let urls: [URL]

    func body(content: Content) -> some View {
        let p = urls.map { model.sinkProgress($0) }.max() ?? 0
        let sinking = urls.contains { model.isSinking($0) }
        content
            .offset(y: sinking ? 40 * p : 0)
            .opacity(sinking ? max(1 - p, 0.02) : 1)
            .overlay(alignment: .bottom) {
                if sinking {
                    Ellipse()
                        .stroke(Theme.lethe.opacity(0.35 * (1 - p)), lineWidth: 0.8)
                        .frame(width: 40 + 120 * p, height: 8 + 18 * p)
                        .offset(y: 46 * p)
                        .allowsHitTesting(false)
                }
            }
            .animation(.linear(duration: 0.25), value: p)
            .animation(.spring(duration: 0.4), value: sinking)
    }
}

extension View {
    func sinking(model: AppModel, urls: [URL]) -> some View {
        modifier(Sinking(model: model, urls: urls))
    }
}

import SwiftUI

/// The bottom strip: the River of Memory, with an unrolled bundle above it when one is open.
struct RiverView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            if let id = model.expanded, let bundle = model.snapshot.river.first(where: { $0.id == id }) {
                UnrolledBundle(model: model, bundle: bundle)
                    .frame(height: Theme.bottomStripExpandedHeight - Theme.bottomStripHeight)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            RiverBand(model: model)
                .frame(height: Theme.bottomStripHeight)
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .animation(.easeInOut(duration: 0.35), value: model.expanded)
    }
}

/// Water, inscriptions and the drifting bundles.
private struct RiverBand: View {
    @ObservedObject var model: AppModel

    var body: some View {
        let today = model.today()
        let river = model.snapshot.river
        let perDay = Dictionary(grouping: river, by: \.id.day).mapValues(\.count)

        ZStack(alignment: .bottom) {
            Water()
                .frame(height: Theme.riverHeight)
                .allowsHitTesting(false)

            VStack {
                HStack {
                    inscription("ΜΝΗΜΟΣΥΝΗ", opacity: 0.85)
                    Spacer()
                    inscription("ΛΗΘΗ →", opacity: 0.5)
                }
                Spacer()
            }
            .padding(.horizontal, 40)
            .padding(.top, 6)
            .frame(height: Theme.riverHeight)
            .allowsHitTesting(false)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .bottom, spacing: 190 - BundleStack.width) {
                    ForEach(river) { bundle in
                        BundleStack(model: model, bundle: bundle,
                                    label: Labels.bundle(bundle.id, dayHasSeveral: (perDay[bundle.id.day] ?? 0) > 1,
                                                         currentYear: today.year),
                                    age: bundle.id.day.days(until: today, calendar: model.calendar))
                    }
                }
                .padding(.leading, 90)
                .padding(.trailing, 260)
                .padding(.bottom, 14)
                .frame(height: Theme.bottomStripHeight, alignment: .bottom)
            }
            .frame(height: Theme.bottomStripHeight)

            LetheZone(model: model)
                .padding(.trailing, 24)
                .padding(.bottom, 14)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func inscription(_ text: String, opacity: Double) -> some View {
        Text(text)
            .font(Theme.inscription(11))
            .tracking(4)
            .foregroundStyle(Theme.riverText.opacity(opacity))
    }
}

/// A faint blue-grey band with a few slowly drifting glints.
private struct Water: View {
    @State private var drift = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.water.opacity(0), Theme.water.opacity(Theme.waterOpacity), Theme.water.opacity(0)],
                           startPoint: .top, endPoint: .bottom)
            GeometryReader { proxy in
                Canvas { ctx, size in
                    var rng = SeededRandom(seed: 7)
                    for _ in 0..<52 {
                        let x = rng.next() * size.width
                        let y = 10 + rng.next() * (size.height - 20)
                        let len = 20 + rng.next() * 60
                        var p = Path()
                        p.move(to: CGPoint(x: x, y: y))
                        p.addLine(to: CGPoint(x: x + len, y: y))
                        ctx.stroke(p, with: .color(.white.opacity(0.15 + rng.next() * 0.35)), lineWidth: 0.8)
                    }
                }
                .frame(width: proxy.size.width * 2)
                .offset(x: drift ? -proxy.size.width : 0)
                .animation(.linear(duration: 240).repeatForever(autoreverses: false), value: drift)
            }
            .clipped()
        }
        .onAppear { drift = true }
    }
}

/// Deterministic pseudo-random numbers in 0..<1 (so the glints never jump between redraws).
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> CGFloat {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return CGFloat(state >> 11) / CGFloat(1 << 53)
    }
}

/// One bundle: up to three screenshots stacked askew, with its Roman date below.
struct BundleStack: View {
    static let width: CGFloat = 112
    static let cardSize = CGSize(width: 78, height: 52)

    @ObservedObject var model: AppModel
    let bundle: RiverBundle
    let label: String
    let age: Int

    @State private var hovering = false
    @State private var showCaption = false

    var body: some View {
        let fade = Fade.appearance(age: age)
        let lit = hovering && !model.isDragging
        VStack(spacing: 10) {
            ZStack {
                ForEach(Array(bundle.shots.prefix(3).enumerated().reversed()), id: \.element.id) { j, shot in
                    ShotCard(shot: shot, size: Self.cardSize, shadow: true)
                        .rotationEffect(.degrees(Double(j - 1) * 2))
                        .offset(x: CGFloat(j) * 7, y: CGFloat(j) * -5)
                }
            }
            .saturation(lit ? 1 : fade.saturation)
            .shadow(color: Theme.glow.opacity(lit ? 0.7 : 0), radius: 8)
            .overlay(alignment: .top) {
                if showCaption {
                    Text("ἀνάμνησις · 回忆")
                        .font(.custom("Palatino-Italic", size: 15))
                        .foregroundStyle(Theme.riverTextHover)
                        .fixedSize()
                        .offset(y: -34)
                        .transition(.opacity)
                }
            }

            Text(label)
                .font(Theme.inscription(12))
                .tracking(2)
                .foregroundStyle(lit ? Theme.riverTextHover : Theme.riverText)
                .fixedSize()
        }
        .frame(width: Self.width)
        .opacity(lit ? 1 : fade.opacity)
        .scaleEffect(lit ? 1.28 : 1, anchor: .bottom)
        .offset(y: lit ? -24 : 0)
        .animation(.easeOut(duration: 0.3), value: lit)
        .contentShape(Rectangle())
        .onHover { on in
            hovering = on
            guard on else { withAnimation { showCaption = false }; return }
            withAnimation(.easeIn(duration: 0.3)) { showCaption = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeOut(duration: 0.6)) { showCaption = false }
            }
        }
        .sinking(model: model, urls: bundle.shots.map(\.url))
        .onTapGesture {
            let urls = bundle.shots.map(\.url)
            if urls.contains(where: model.isSinking) {
                model.rescue(urls)
            } else {
                model.expanded = model.expanded == bundle.id ? nil : bundle.id
            }
        }
        .onDrag {
            model.rescue(bundle.shots.map(\.url))
            model.beginDrag()
            return NSItemProvider(contentsOf: bundle.url) ?? NSItemProvider()
        }
        .contextMenu {
            Button("展开") { model.expanded = bundle.id }
            Button("在 Finder 中显示") { NSWorkspace.shared.activateFileViewerSelecting([bundle.url]) }
            Divider()
            Button("整束沉入忘川") { model.sink([bundle.url]) }
        }
    }
}

/// An opened bundle, unrolled above the river like a scroll: every screenshot, fully interactive.
private struct UnrolledBundle: View {
    @ObservedObject var model: AppModel
    let bundle: RiverBundle

    var body: some View {
        let urls = bundle.shots.map(\.url)
        ZStack {
            Color.white.opacity(0.001) // catches clicks on empty space
                .onTapGesture { model.expanded = nil }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .center, spacing: 22) {
                    ForEach(bundle.shots) { shot in
                        let size = Thumb.fit(ThumbnailCache.shared.pixelSize(shot.url))
                        ShotCard(shot: shot, size: size)
                            .shotInteractions(model: model, shot: shot, size: size, siblings: urls)
                            .sinking(model: model, urls: [shot.url])
                            .zIndex(model.hovered == shot.url ? 10 : 0)
                    }
                }
                .padding(.horizontal, 60)
                .frame(minWidth: 0, maxHeight: .infinity)
            }
            .scrollClipDisabled()
        }
    }
}

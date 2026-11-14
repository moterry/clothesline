import AppKit
import Combine
import SwiftUI

/// The app's single source of truth for the UI. The disk is the real state; this mirrors it.
@MainActor
final class AppModel: ObservableObject {
    let paths: LibraryPaths
    let settings: Settings
    let calendar = Calendar.current

    @Published private(set) var snapshot = LibrarySnapshot.empty
    /// Screenshots that just arrived on the line (animate in).
    @Published var arriving: Set<URL> = []
    @Published var expanded: BundleID?
    @Published var isDragging = false
    /// The screenshot under the pointer (raised above its neighbours).
    @Published var hovered: URL?
    @Published private(set) var summoned = false
    /// Advances while something is sinking, so sinking visuals can read progress.
    @Published private(set) var now = Date()

    /// Called when summoned changes (the app delegate lifts or lowers the strip windows).
    var onSummonChange: ((Bool) -> Void)?
    /// Called when the river's expanded state changes (the bottom strip resizes).
    var onExpandChange: ((Bool) -> Void)?

    private(set) lazy var lethe: LetheQueue = { [paths] in
        LetheQueue { try Lethe.permanentlyDelete($0, paths: paths) }
    }()
    private var letheTimer: Timer?
    private var expandObserver: AnyCancellable?

    init(paths: LibraryPaths, settings: Settings) {
        self.paths = paths
        self.settings = settings
        expandObserver = $expanded.map { $0 != nil }.removeDuplicates().sink { [weak self] on in
            self?.onExpandChange?(on)
        }
    }

    var keeper: RopeKeeper {
        RopeKeeper(paths: paths, calendar: calendar, capacity: settings.capacity)
    }

    func today() -> Day { Day(Date(), calendar: calendar) }

    /// Launch, wake and midnight: make sure folders exist, cut a stale line, hang anything waiting.
    func start() {
        try? paths.ensureExists()
        cutIfStale()
        ingest()
    }

    func cutIfStale() {
        _ = try? keeper.cutIfStale(now: Date())
        refresh()
    }

    func refresh() {
        if let s = try? LibraryScanner.scan(paths) { snapshot = s }
    }

    private var settling = false
    private var settleAgain = false

    /// Hangs pending screenshots (no-op while paused), once their files have finished writing.
    /// Only one stability check runs at a time; events during it schedule one more pass.
    func ingest() {
        guard !settings.paused else { refresh(); return }
        if settling { settleAgain = true; return }
        settling = true
        let root = paths.root
        StableFiles.whenStable({ FileOps.candidates(in: root) }) { [weak self] in
            guard let self else { return }
            self.settling = false
            self.ingestNow()
            if self.settleAgain {
                self.settleAgain = false
                self.ingest()
            }
        }
    }

    private func ingestNow() {
        guard !settings.paused else { return }
        let events = (try? keeper.catchUp(now: Date())) ?? []
        let hung = events.compactMap { e -> URL? in if case .hung(let u) = e { return u } else { return nil } }
        withAnimation(.easeInOut(duration: 1.6)) { refresh() }
        guard !hung.isEmpty else { return }
        arriving.formUnion(hung)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            self?.arriving.subtract(hung)
        }
    }

    // MARK: Lethe

    /// Only screenshots inside the library can sink; bundle folders sink all their screenshots.
    func sink(_ urls: [URL]) {
        let files = paths.filesToSink(urls).filter { !isSinking($0) }
        guard !files.isEmpty else { return }
        _ = lethe.sink(files, now: Date())
        now = Date()
        startLetheTimer()
    }

    func rescue(_ url: URL) {
        guard let id = lethe.sinkID(containing: url) else { return }
        _ = lethe.rescue(id)
        now = Date()
    }

    func rescue(_ urls: [URL]) {
        urls.forEach(rescue)
    }

    func isSinking(_ url: URL) -> Bool { lethe.sinkID(containing: url) != nil }

    func sinkProgress(_ url: URL) -> Double {
        guard let id = lethe.sinkID(containing: url) else { return 0 }
        return lethe.progress(id, now: now)
    }

    private func startLetheTimer() {
        guard letheTimer == nil else { return }
        letheTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.letheTick() }
        }
    }

    private func letheTick() {
        now = Date()
        let gone = lethe.commitDue(now: now)
        if !gone.isEmpty { refresh() }
        if lethe.isEmpty {
            letheTimer?.invalidate()
            letheTimer = nil
        }
    }

    // MARK: Dragging

    private var dragPoll: Timer?
    /// When true, starting a drag lifts the strips above all windows (set from the proof-of-concept result).
    static let summonOnDrag = false

    /// What our own drag is carrying (screenshot files or a bundle folder). Lethe sinks exactly these:
    /// the drop's pasteboard data cannot be read back as file URLs on macOS, so it is not used.
    private(set) var draggedURLs: [URL] = []
    private var dragEndedAt = Date.distantPast

    /// A drag began from one of our screenshots. SwiftUI reports no end, so poll the mouse button.
    func beginDrag(_ urls: [URL]) {
        draggedURLs = urls
        isDragging = true
        if Self.summonOnDrag { setSummoned(true) }
        dragPoll?.invalidate()
        dragPoll = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] timer in
            guard NSEvent.pressedMouseButtons & 1 == 0 else { return }
            timer.invalidate()
            MainActor.assumeIsolated { self?.endDrag() }
        }
    }

    private func endDrag() {
        dragPoll = nil
        dragEndedAt = Date()
        isDragging = false
        if summoned { setSummoned(false) }
    }

    /// A drop landed on Lethe. Accepted only for our own drag (in progress, or ended within the last second
    /// in case the mouse-up was noticed first). Returns whether anything started sinking.
    @discardableResult
    func dropOnLethe() -> Bool {
        guard !draggedURLs.isEmpty, isDragging || Date().timeIntervalSince(dragEndedAt) < 1 else { return false }
        let urls = draggedURLs
        draggedURLs = []
        sink(urls)
        return paths.filesToSink(urls).contains(where: isSinking)
    }

    // MARK: Summon

    func setSummoned(_ on: Bool) {
        guard on != summoned else { return }
        summoned = on
        onSummonChange?(on)
    }
}

import CoreServices
import Foundation

/// Watches a folder tree (FSEvents, recursive) and calls `onChange` on the main queue, debounced.
final class FolderWatcher {
    private let url: URL
    private let onChange: () -> Void
    private var stream: FSEventStreamRef?
    private var pending: DispatchWorkItem?

    init(url: URL, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
    }

    func start() {
        guard stream == nil else { return }
        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
                                           retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue().fire()
        }
        stream = FSEventStreamCreate(nil, callback, &context, [url.path] as CFArray,
                                     FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.2,
                                     FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer))
        guard let stream else { return }
        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    deinit { stop() }

    private func fire() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.onChange() }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }
}

/// Waits until every file's size is unchanged across two reads `interval` apart.
enum StableFiles {
    static func sizes(_ urls: [URL]) -> [URL: Int] {
        Dictionary(uniqueKeysWithValues: urls.map { url in
            (url, (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? -1)
        })
    }

    static func whenStable(_ urls: @escaping () -> [URL], interval: TimeInterval = 0.3, then: @escaping () -> Void) {
        let before = sizes(urls())
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
            let after = sizes(urls())
            if after == before && !after.values.contains(0) {
                then()
            } else {
                whenStable(urls, interval: interval, then: then)
            }
        }
    }
}

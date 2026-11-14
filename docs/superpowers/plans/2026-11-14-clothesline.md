# Clothesline (晾衣绳) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu-bar app that catches every screenshot that was not dragged away, hangs it on a line at the top of the desktop, rolls full or day-old lines into a river of bundles along the bottom, and permanently deletes only what the user drops into Lethe.

**Architecture:** There are two layers. `Sources/Core` holds pure, Foundation-only logic: library folders, ingest and cut rules, Lethe queue, geometry, labels and system settings. It is covered by Swift Testing tests. `Sources/App` holds the AppKit + SwiftUI shell: two borderless strip windows at the desktop layer, a folder watcher, a menu bar item and a global hotkey. The folder structure on disk *is* the state. There is no database.

**Tech Stack:** Swift 6.3.3 (Command Line Tools only, no Xcode), AppKit, SwiftUI, QuickLookUI, QuickLookThumbnailing, ServiceManagement, Carbon (hotkey), Swift Testing. Built with plain `swiftc` scripts, because SwiftPM manifests fail to link on this machine.

**Spec:** `docs/2026-11-14-晾衣绳-design.en.md` (Chinese twin: `docs/2026-11-14-晾衣绳-design.zh.md`). Visual reference: the light image in `.superpowers/brainstorm/64985-1794648397/content/clothesline-v2.html`.

> **中文概要：** 先搭好命令行构建和测试，再做一个"桌面层窗口 + 拖进应用 + 召唤快捷键"的最小验证，需要你亲手试一下。然后依次做核心逻辑（文件夹、挂绳与剪断、忘川删除、几何与标签、系统截图位置、导入旧截图），最后做界面（绳、截图交互、河、忘川、菜单栏与首次启动、打包成 晾衣绳.app）。每个任务完成后提交一次。

## Global Constraints

- Runs on this Mac only: macOS 26.2, Apple silicon. Compile with no `-target` flag, so the host OS is used.
- No Xcode, no SwiftPM, no third-party dependencies, no network access.
- Library root: `~/Pictures/Clothesline/`, with subfolders `Rope/` and `River/`. Bundle folder name: `yyyy-MM-dd · <Roman ordinal>`, for example `2026-11-14 · II`. The separator is space, U+00B7, space.
- Overriding the library root (for tests and demos): environment variable `CLOTHESLINE_ROOT`.
- Line capacity: default 12. Allowed values: 8, 12, 16.
- Lethe sink delay: 5 seconds. Deletion is permanent (`FileManager.removeItem`), never via the Trash, and happens only when the delay ends.
- Image extensions that count (case-insensitive): `png jpg jpeg heic tiff tif pdf`. Ignore dotfiles, folders and `.mov`.
- Summon hotkey: ⌃⌥L.
- App bundle: `晾衣绳.app`. Executable `Clothesline`. Bundle id `local.clothesline`. `LSUIElement` is true. Installed to `~/Applications/`. Ad-hoc signed (`codesign -s -`).
- All dates are shown in Roman numerals. Today's label: `HODIE · <day> · <month>`. River labels: `ΜΝΗΜΟΣΥΝΗ` on the left, `ΛΗΘΗ →` on the right. Hover caption: `ἀνάμνησις · 回忆`.
- Inscription typeface: system `Palatino-Roman` in capitals with wide tracking. It is verified to cover the Greek, including `ἀ`. Chinese text uses `Songti SC`.
- Colors (light palette only in v1): line `#4a4540` 1.1pt; peg `#9a7b4f` 6×17pt; screenshot frame 3pt white with a shadow of y+3, blur 3, 20% black; label ink `#7a7268`; river water `#4f6f8f` at 16% opacity in the center, fading to 0; glints white at 15–50%; river text `#8a7650`; hover highlight `#9a7b3c`; recollection glow `#e8c77a` with an 8pt blur.
- Never lose a screenshot without the user's own action. Never overwrite an existing file. Moves rename on collision.

## Review Focus

1. **A burst of screenshots arrives at once.** For example, ⌘⇧3 with two displays writes two files in the same second, or the app catches up a backlog. Every file must hang in creation order (ties broken by file name), and none may be dropped or overwritten. Test: Task 4 `ingestBurstKeepsAllInOrder`.
2. **File name collisions when moving.** A Desktop import or a cut may meet a file with the same name already in the destination. The moved file must be renamed `name (2).png` and never overwrite. Test: Task 3 `moveUniqueRenamesOnCollision`, Task 7 `importDoesNotOverwrite`.
3. **The app was not running for several days.** Screenshots pile up in the root across dates. On catch-up each file must be grouped by its *own* day, not by today. Earlier days become bundles and the line keeps only the latest day's tail. Test: Task 4 `backlogAcrossDaysGroupsByOwnDay`.
4. **The Mac sleeps through midnight, or the app launches the next morning.** A line holding yesterday's screenshots must be cut on wake or launch. Test: Task 4 `cutIfStaleCutsYesterdaysRope`. Wiring: Task 12.
5. **Files change underneath the app.** The user deletes or moves a file in Finder, or a sinking file is already gone. Nothing may crash. A missing file at commit time counts as deleted, and stray non-image files are ignored. Test: Task 5 `commitToleratesMissingFile`, Task 3 `scanIgnoresNonImagesAndDotfiles`.

---

## File Structure

```
Sources/Core/                  (Foundation + CoreGraphics only; compiled into both app and tests)
  Roman.swift                  Roman numerals
  Day.swift                    calendar day value type
  BundleID.swift               bundle identity + folder-name format/parse
  Labels.swift                 HODIE / bundle label strings
  LibraryPaths.swift           root, Rope/, River/, env override
  FileOps.swift                candidate filter, creation date, moveUnique
  LibraryScanner.swift         Shot, RiverBundle, LibrarySnapshot, scan()
  RopeKeeper.swift             ingest + cut rules
  Lethe.swift                  LetheQueue + permanent delete
  Fade.swift                   age → opacity/saturation
  RopeGeometry.swift           curve, slot layout, tilt
  ScreenshotLocation.swift     com.apple.screencapture location adopt/restore
  DesktopImport.swift          find + import old Desktop screenshots
Sources/App/
  ClotheslineApp.swift         @main, NSApplication bootstrap, accessory policy
  StripWindow.swift            desktop-layer borderless window, summon level switching
  HotKey.swift                 Carbon ⌃⌥L registration
  Theme.swift                  colors, fonts, metrics
  AppModel.swift               @MainActor ObservableObject: snapshot, sinking, expansion, drag state
  Settings.swift               UserDefaults-backed preferences
  FolderWatcher.swift          watches root, debounces, waits for stable size
  ThumbnailCache.swift         QLThumbnailGenerator + NSCache
  ShotCard.swift               one framed screenshot + hover/click/drag/context menu
  QuickLook.swift              QLPreviewPanel controller
  RopeView.swift               top strip content
  RiverView.swift              bottom strip content, bundles, scrolling, expansion
  LetheZone.swift              drop target + sinking visuals
  MenuBar.swift                status item + menu
  Onboarding.swift             first-launch window (consent + Desktop import)
Tests/
  Support/TestMain.swift       Swift Testing entry point
  Support/Fixtures.swift       temp library, fake images, fixed calendar
  *Tests.swift                 one file per Core unit
Resources/Info.plist
scripts/test.sh  scripts/build.sh  scripts/package.sh  scripts/seed-demo.sh
docs/poc-notes.md              result of the Task 2 proof of concept
```

---

### Task 1: Toolchain, test harness, Roman numerals and labels

**Files:**
- Create: `scripts/test.sh`, `scripts/build.sh`, `.gitignore`, `Tests/Support/TestMain.swift`, `Tests/Support/Fixtures.swift`
- Create: `Sources/Core/Roman.swift`, `Sources/Core/Day.swift`, `Sources/Core/BundleID.swift`, `Sources/Core/Labels.swift`
- Create: `Sources/App/ClotheslineApp.swift` (placeholder only, so `build.sh` has something to compile)
- Test: `Tests/RomanTests.swift`, `Tests/LabelTests.swift`

**Interfaces:**
- Produces:
  - `enum Roman { static func numeral(_ n: Int) -> String }` (1…3999)
  - `struct Day: Hashable, Comparable, Sendable { let year: Int; let month: Int; let day: Int; init(_ date: Date, calendar: Calendar); init(year:month:day:); func startDate(calendar: Calendar) -> Date; func days(until other: Day, calendar: Calendar) -> Int }`
  - `struct BundleID: Hashable, Comparable, Sendable { let day: Day; let ordinal: Int; var folderName: String; init?(folderName: String); init(day:ordinal:) }`. Comparable order: newer day first, then higher ordinal first.
  - `enum Labels { static func today(_ day: Day) -> String; static func bundle(_ id: BundleID, dayHasSeveral: Bool, currentYear: Int) -> String }`
  - Fixtures: `let testCalendar: Calendar` (gregorian, `TimeZone(secondsFromGMT: 8*3600)`), `func at(_ s: String) -> Date` (format `yyyy-MM-dd HH:mm`), `func makeTempLibrary() -> LibraryPaths` (added in Task 3), `func makeImage(_ url: URL, created: Date)` (added in Task 3)

- [ ] **Step 1: Initialise git and the harness**

`git init`. `.gitignore` contains `build/` and `.superpowers/`.

`scripts/test.sh` (these exact flags were verified on this machine):

```bash
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
CLT=/Library/Developer/CommandLineTools
FW=$CLT/Library/Developer/Frameworks
LIB=$CLT/Library/Developer/usr/lib
mkdir -p build
swiftc -parse-as-library \
  -plugin-path "$CLT/usr/lib/swift/host/plugins/testing" \
  -F "$FW" -Xlinker -rpath -Xlinker "$FW" -Xlinker -rpath -Xlinker "$LIB" \
  Sources/Core/*.swift Tests/*.swift Tests/Support/*.swift -o build/ClotheslineTests
./build/ClotheslineTests "$@"
```

`Tests/Support/TestMain.swift`:

```swift
import Foundation
import Testing
@main struct TestMain { static func main() async { exit(await Testing.__swiftPMEntryPoint() as CInt) } }
```

`scripts/build.sh`: `swiftc -parse-as-library -O Sources/Core/*.swift Sources/App/*.swift -o build/Clothesline`. `ClotheslineApp.swift` starts as an `@main` struct that only runs `NSApplication.shared` with `.accessory` policy.

- [ ] **Step 2: Write failing tests**

```swift
@Test func romanBasics() {
  #expect(Roman.numeral(1) == "I"); #expect(Roman.numeral(4) == "IV"); #expect(Roman.numeral(9) == "IX")
  #expect(Roman.numeral(14) == "XIV"); #expect(Roman.numeral(28) == "XXVIII"); #expect(Roman.numeral(2025) == "MMXXV")
}
@Test func dayFromDateUsesCalendar() { #expect(Day(at("2026-11-14 23:59"), calendar: testCalendar) == Day(year: 2026, month: 11, day: 14)) }
@Test func dayDistance() { #expect(Day(year: 2026, month: 10, day: 15).days(until: Day(year: 2026, month: 11, day: 14), calendar: testCalendar) == 30) }
@Test func folderNameRoundTrip() {
  let id = BundleID(day: Day(year: 2026, month: 11, day: 14), ordinal: 2)
  #expect(id.folderName == "2026-11-14 · II"); #expect(BundleID(folderName: "2026-11-14 · II") == id)
  #expect(BundleID(folderName: "2026-11-14") == nil); #expect(BundleID(folderName: "notes") == nil)
}
@Test func bundleOrderNewestFirst() {
  let a = BundleID(day: Day(year: 2026, month: 11, day: 14), ordinal: 1), b = BundleID(day: Day(year: 2026, month: 11, day: 14), ordinal: 2)
  let c = BundleID(day: Day(year: 2026, month: 11, day: 13), ordinal: 1)
  #expect([c, a, b].sorted() == [b, a, c])
}
@Test func labels() {
  #expect(Labels.today(Day(year: 2026, month: 11, day: 14)) == "HODIE · XIV · XI")
  let one = BundleID(day: Day(year: 2026, month: 11, day: 13), ordinal: 1)
  #expect(Labels.bundle(one, dayHasSeveral: false, currentYear: 2026) == "XIII · XI")
  let two = BundleID(day: Day(year: 2026, month: 11, day: 14), ordinal: 2)
  #expect(Labels.bundle(two, dayHasSeveral: true, currentYear: 2026) == "XIV · XI · II")
  let old = BundleID(day: Day(year: 2025, month: 11, day: 14), ordinal: 1)
  #expect(Labels.bundle(old, dayHasSeveral: false, currentYear: 2026) == "XIV · XI · MMXXV")
  let oldTwo = BundleID(day: Day(year: 2025, month: 11, day: 14), ordinal: 2)
  #expect(Labels.bundle(oldTwo, dayHasSeveral: true, currentYear: 2026) == "XIV · XI · MMXXV · II")
}
```

- [ ] **Step 3: Run `scripts/test.sh`.** Expected: compile errors (types not defined).
- [ ] **Step 4: Implement `Roman`, `Day`, `BundleID`, `Labels`** with the signatures above. The year is shown only when it differs from `currentYear`; the ordinal only when `dayHasSeveral`.
- [ ] **Step 5: Run `scripts/test.sh` and `scripts/build.sh`.** Expected: `✔ Test run with 6 tests … passed` and the build exits 0.
- [ ] **Step 6: Commit** `feat: build/test harness, Roman numerals, bundle labels`

---

### Task 2: Proof of concept — desktop-layer strips, drag into apps, summon

The spec (§5.5, §9) requires this before anything else is built on it. The result decides whether summon becomes the main way to get screenshots out.

**Files:**
- Create: `Sources/App/StripWindow.swift`, `Sources/App/HotKey.swift`
- Modify: `Sources/App/ClotheslineApp.swift` (temporary PoC content)
- Create: `docs/poc-notes.md`

**Interfaces:**
- Produces:
  - `final class StripWindow: NSPanel { init(frame: NSRect, content: NSView); func setSummoned(_ on: Bool) }`. It is borderless, non-activating, `isOpaque = false`, `backgroundColor = .clear` and `hasShadow = false`. Its `collectionBehavior` is `[.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]`. Resting level: `NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)`. Summoned level: `.floating`.
  - `final class HotKey { init(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) }`. Uses Carbon `RegisterEventHotKey`, which needs no Accessibility permission. Use ⌃⌥L = `kVK_ANSI_L` with `controlKey | optionKey`.

- [ ] **Step 1: Build the PoC.** A top strip, 300pt tall, just below the menu bar, showing one framed sample image that can be dragged out as a file. Use a PNG written to `build/poc.png`, and SwiftUI `.onDrag { NSItemProvider(contentsOf: url)! }` inside an `NSHostingView`. A bottom strip, 170pt tall, above the Dock, filled with a faint tint. ⌃⌥L toggles `setSummoned` on both strips. `Esc` while summoned un-summons them.
- [ ] **Step 2: Run `scripts/build.sh && ./build/Clothesline`.** Expected: the process stays running and no window covers app windows.
- [ ] **Step 3: Ask the user to try four checks and report the result of each.**
  - A. Reveal the desktop with the four-finger spread, then with `F11`. Are both strips visible, and does hovering or clicking the image respond?
  - B. With the desktop revealed, drag the image toward a chat app. Do windows come back, and does the drop succeed?
  - C. Press ⌃⌥L over normal windows. Do the strips come forward? Can the image be dragged into the chat window behind them? Does `Esc` send them back?
  - D. Do the strips stay out of the Dock and `⌘Tab`, and appear on every Space?
- [ ] **Step 4: Write `docs/poc-notes.md`** with each check's outcome. Then record the decision: if B fails, summon is the primary way to drag out and the onboarding text in Task 12 mentions ⌃⌥L; if B passes, summon stays as a convenience.
- [ ] **Step 5: Commit** `chore: desktop-layer strip + summon proof of concept`

---

### Task 3: Library on disk — paths, file filter, safe moves, scanner

**Files:**
- Create: `Sources/Core/LibraryPaths.swift`, `Sources/Core/FileOps.swift`, `Sources/Core/LibraryScanner.swift`
- Modify: `Tests/Support/Fixtures.swift` (add `makeTempLibrary`, `makeImage`)
- Test: `Tests/LibraryTests.swift`

**Interfaces:**
- Consumes: `Day`, `BundleID` (Task 1)
- Produces:
  - `struct LibraryPaths: Sendable { let root: URL; var rope: URL { get }; var river: URL { get }; static func standard(environment: [String: String] = ProcessInfo.processInfo.environment) -> LibraryPaths; func ensureExists() throws }`. `standard` honors `CLOTHESLINE_ROOT`, otherwise uses `~/Pictures/Clothesline`.
  - `enum FileOps { static func isCandidate(_ url: URL) -> Bool; static func creationDate(_ url: URL) -> Date; static func moveUnique(_ src: URL, into dir: URL) throws -> URL }`
  - `struct Shot: Hashable, Identifiable, Sendable { let url: URL; let created: Date; var id: URL { url } }`
  - `struct RiverBundle: Identifiable, Sendable { let id: BundleID; let url: URL; let shots: [Shot] }`. Shots are oldest first.
  - `struct LibrarySnapshot: Sendable { let rope: [Shot]; let river: [RiverBundle]; let pending: [URL] }`. `rope` is oldest first; `river` is sorted by `BundleID` (newest first); `pending` holds candidate files in the root.
  - `enum LibraryScanner { static func scan(_ paths: LibraryPaths) throws -> LibrarySnapshot }`

- [ ] **Step 1: Write failing tests**

```swift
@Test func standardHonorsEnvironment() { #expect(LibraryPaths.standard(environment: ["CLOTHESLINE_ROOT": "/tmp/x"]).root.path == "/tmp/x") }
@Test func candidates() {
  #expect(FileOps.isCandidate(URL(fileURLWithPath: "/a/截屏 2026-11-14 10.00.00.PNG")))
  #expect(!FileOps.isCandidate(URL(fileURLWithPath: "/a/.截屏 2026.png")))
  #expect(!FileOps.isCandidate(URL(fileURLWithPath: "/a/录屏.mov")))
}
@Test func moveUniqueRenamesOnCollision() throws {
  let lib = makeTempLibrary(); try lib.ensureExists()
  makeImage(lib.root.appending(path: "a.png"), created: at("2026-11-14 10:00"))
  makeImage(lib.rope.appending(path: "a.png"), created: at("2026-11-14 09:00"))
  let moved = try FileOps.moveUnique(lib.root.appending(path: "a.png"), into: lib.rope)
  #expect(moved.lastPathComponent == "a (2).png")
  #expect(FileManager.default.fileExists(atPath: lib.rope.appending(path: "a.png").path))
}
@Test func scanSortsRopeAndRiver() throws {
  let lib = makeTempLibrary(); try lib.ensureExists()
  makeImage(lib.rope.appending(path: "b.png"), created: at("2026-11-14 11:00"))
  makeImage(lib.rope.appending(path: "a.png"), created: at("2026-11-14 10:00"))
  for name in ["2026-11-13 · I", "2026-11-14 · I"] {
    let dir = lib.river.appending(path: name); try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    makeImage(dir.appending(path: "x.png"), created: at("2026-11-13 08:00"))
  }
  let s = try LibraryScanner.scan(lib)
  #expect(s.rope.map(\.url.lastPathComponent) == ["a.png", "b.png"])
  #expect(s.river.map(\.id.folderName) == ["2026-11-14 · I", "2026-11-13 · I"])
}
@Test func scanIgnoresNonImagesAndDotfiles() throws {
  let lib = makeTempLibrary(); try lib.ensureExists()
  try Data().write(to: lib.root.appending(path: "notes.txt")); try Data().write(to: lib.root.appending(path: ".tmp.png"))
  try FileManager.default.createDirectory(at: lib.river.appending(path: "random folder"), withIntermediateDirectories: true)
  makeImage(lib.root.appending(path: "s.png"), created: at("2026-11-14 10:00"))
  let s = try LibraryScanner.scan(lib)
  #expect(s.pending.map(\.lastPathComponent) == ["s.png"]); #expect(s.river.isEmpty)
}
```

`makeImage` writes a valid 1×1 PNG and sets `.creationDate` with `FileManager.setAttributes`. `makeTempLibrary` returns `LibraryPaths(root:)` under `FileManager.default.temporaryDirectory/UUID`.

- [ ] **Step 2: Run `scripts/test.sh`.** Expected: FAIL (types missing).
- [ ] **Step 3: Implement the three files.** `moveUnique` tries `name (2).ext`, `name (3).ext`, and so on. River folders whose names do not parse as `BundleID` are ignored.
- [ ] **Step 4: Run `scripts/test.sh`.** Expected: all pass.
- [ ] **Step 5: Commit** `feat: library folders, safe moves, scanner`

---

### Task 4: RopeKeeper — hanging and cutting

**Files:**
- Create: `Sources/Core/RopeKeeper.swift`
- Test: `Tests/RopeKeeperTests.swift`

**Interfaces:**
- Consumes: `LibraryPaths`, `FileOps`, `LibraryScanner`, `Day`, `BundleID`
- Produces:
  - `enum RopeEvent: Equatable, Sendable { case hung(URL); case cut(BundleID) }`
  - `struct RopeKeeper { let paths: LibraryPaths; let calendar: Calendar; var capacity: Int; func ingestPending() throws -> [RopeEvent]; func cutIfStale(now: Date) throws -> RopeEvent?; func cut() throws -> RopeEvent? }`

Rules (the spec leaves exact timing open; this algorithm is the decision):

```
ingestPending: for each pending file sorted by (creationDate, fileName):
    d = Day(file.created)
    if rope non-empty and Day(rope.first.created) != d  → cut()
    if rope.count >= capacity                            → cut()
    moveUnique(file, into: rope); emit .hung(newURL)
cut(): if rope empty → nil
    day = Day(rope.first.created); ordinal = 1 + max ordinal of existing bundles for that day (0 if none)
    create River/<BundleID(day, ordinal).folderName>/, moveUnique every rope file into it; emit .cut(id)
cutIfStale(now): if rope non-empty and Day(rope.first.created) < Day(now) → cut()
```

The line therefore shows up to `capacity` screenshots. It is cut when the next one arrives, at midnight, or on wake/launch for a previous day.

- [ ] **Step 1: Write failing tests**

```swift
@Test func hangsInOrder() throws { /* two pending files 10:00, 10:05 → events [.hung(a), .hung(b)], rope == [a, b], root has no candidates */ }
@Test func cutsWhenFullOnNextArrival() throws {
  // capacity 3, four pending files on 2026-11-14
  // events: hung, hung, hung, cut(2026-11-14 · I), hung ; rope.count == 1; river[0].shots.count == 3
}
@Test func secondCutSameDayGetsOrdinalII() throws { /* capacity 2, five files same day → bundles "2026-11-14 · II", "2026-11-14 · I"; rope.count == 1 */ }
@Test func ingestBurstKeepsAllInOrder() throws {
  // three files with identical creation date, names c.png, a.png, b.png → rope names == ["a.png","b.png","c.png"]; nothing left in root
}
@Test func backlogAcrossDaysGroupsByOwnDay() throws {
  // capacity 12; files: 2 on 11-12, 3 on 11-13, 1 on 11-14
  // river ids == ["2026-11-13 · I", "2026-11-12 · I"]; river shot counts [3, 2]; rope.count == 1
}
@Test func cutIfStaleCutsYesterdaysRope() throws {
  // rope holds one file from 2026-11-13 → cutIfStale(now: at("2026-11-14 08:00")) == .cut(2026-11-13 · I)
  // and with rope from today → returns nil and rope unchanged
}
@Test func cutOnEmptyRopeIsNil() throws { #expect(try keeper.cut() == nil) }
```

Write each test fully, using `makeImage`, `makeTempLibrary`, `testCalendar` and `LibraryScanner.scan` for assertions.

- [ ] **Step 2: Run `scripts/test.sh`.** Expected: FAIL.
- [ ] **Step 3: Implement `RopeKeeper`** per the rules block.
- [ ] **Step 4: Run `scripts/test.sh`.** Expected: all pass.
- [ ] **Step 5: Commit** `feat: rope ingest and cut rules`

---

### Task 5: Lethe queue — sinking, rescue, permanent delete

**Files:**
- Create: `Sources/Core/Lethe.swift`
- Test: `Tests/LetheTests.swift`

**Interfaces:**
- Consumes: `LibraryPaths`
- Produces:
  - `struct SinkID: Hashable, Sendable { let raw: UUID }`
  - `final class LetheQueue { init(delay: TimeInterval = 5, remove: @escaping (URL) throws -> Void); func sink(_ urls: [URL], now: Date) -> SinkID; func rescue(_ id: SinkID) -> [URL]?; func sinkID(containing url: URL) -> SinkID?; func progress(_ id: SinkID, now: Date) -> Double; func commitDue(now: Date) -> [URL] }`
  - `enum Lethe { static func permanentlyDelete(_ url: URL, paths: LibraryPaths) throws }`. It removes the file, then removes its parent folder if that folder is a bundle folder inside `River/` and is now empty.

- [ ] **Step 1: Write failing tests**

```swift
@Test func nothingDeletedBeforeDelay() { /* sink at t0; commitDue(t0+4.9) == []; remove never called */ }
@Test func deletedAfterDelay() { /* commitDue(t0+5) == [url]; remove called once with url; a second commitDue returns [] */ }
@Test func rescueCancels() { /* rescue(id) == [url]; commitDue(t0+10) == [] */ }
@Test func progressRuns0to1() { /* progress at t0 == 0, t0+2.5 == 0.5, t0+9 == 1 */ }
@Test func commitToleratesMissingFile() throws {
  // real Lethe.permanentlyDelete as remove; file deleted externally before commit → commitDue returns [url], no crash
}
@Test func permanentDeleteRemovesEmptyBundleFolder() throws {
  // bundle folder with one image → after delete, folder gone; Rope/ itself is never removed even when empty
}
@Test func dropQueueDeletesNothing() { /* create queue, sink, let it deinit without commit → file still exists (deletion only via commitDue) */ }
```

- [ ] **Step 2: Run `scripts/test.sh`.** Expected: FAIL.
- [ ] **Step 3: Implement.** If `remove` throws because the file no longer exists (`NSFileNoSuchFileError`), treat it as deleted. Other errors leave the file in place and drop it from the queue (counts as rescued).
- [ ] **Step 4: Run `scripts/test.sh`.** Expected: all pass.
- [ ] **Step 5: Commit** `feat: Lethe queue with 5s rescue window`

---

### Task 6: Geometry, fade and tilt

**Files:**
- Create: `Sources/Core/RopeGeometry.swift`, `Sources/Core/Fade.swift`
- Test: `Tests/GeometryTests.swift`

**Interfaces:**
- Consumes: `Day`
- Produces:
  - `struct RopeGeometry { init(width: CGFloat); let x0: CGFloat; let x1: CGFloat; let y0: CGFloat; let sag: CGFloat; func y(at x: CGFloat) -> CGFloat; func slope(at x: CGFloat) -> CGFloat; func path() -> CGPath; func layout(_ sizes: [CGSize], names: [String]) -> [Slot] }`. Coordinates are y-down, in the strip's local space.
  - `struct Slot: Equatable { let pin: CGPoint; let size: CGSize; let tiltDegrees: Double }`
  - `enum Thumb { static let maxSize = CGSize(width: 150, height: 120); static func fit(_ pixels: CGSize) -> CGSize }`
  - `enum Tilt { static func jitter(for name: String) -> Double }`. Deterministic, in −1.5…1.5, from an FNV-1a hash of the name.
  - `enum Fade { static func appearance(age days: Int) -> (opacity: Double, saturation: Double) }`

Values from the sketch at width 1440, scaled linearly by `width/1440`: x0 = 50, x1 = width − 50, y0 = 38, sag = 80, first slot starts at x0 + 80, gap 22. The curve is `y = y0 + 4·sag·t·(1−t)` with `t = (x−x0)/(x1−x0)`. Tilt = `atan(slope)·180/π·0.35 + Tilt.jitter(name)`. If the total width (sizes + gaps) exceeds `x1 − 20 − start`, scale every size down uniformly to fit. Pins sit on the curve at each slot's center x.

- [ ] **Step 1: Write failing tests**

```swift
@Test func curveEndsAndMiddle() { let g = RopeGeometry(width: 1440); #expect(g.y(at: g.x0) == 38); #expect(g.y(at: 720) == 118) }
@Test func fitKeepsAspect() { #expect(Thumb.fit(CGSize(width: 3000, height: 2000)) == CGSize(width: 150, height: 100)); #expect(Thumb.fit(CGSize(width: 1000, height: 2000)) == CGSize(width: 60, height: 120)) }
@Test func twelveWideShotsFitOnScreen() {
  let g = RopeGeometry(width: 1440); let slots = g.layout(Array(repeating: CGSize(width: 150, height: 100), count: 12), names: (0..<12).map { "\($0)" })
  #expect(slots.count == 12); #expect(slots.last!.pin.x + slots.last!.size.width / 2 <= g.x1)
  #expect(slots.allSatisfy { abs($0.pin.y - g.y(at: $0.pin.x)) < 0.001 })
}
@Test func jitterStableAndBounded() { #expect(Tilt.jitter(for: "a.png") == Tilt.jitter(for: "a.png")); #expect((-1.5...1.5).contains(Tilt.jitter(for: "截屏 1.png"))) }
@Test func fadeCurve() {
  #expect(Fade.appearance(age: 0) == (1, 1)); #expect(Fade.appearance(age: 30) == (0.45, 0.15))
  #expect(Fade.appearance(age: 400) == (0.45, 0.15)); let m = Fade.appearance(age: 15); #expect(abs(m.opacity - 0.725) < 1e-9 && abs(m.saturation - 0.575) < 1e-9)
}
```

- [ ] **Step 2: Run `scripts/test.sh`.** Expected: FAIL.
- [ ] **Step 3: Implement.** Fade is linear in `min(days, 30)/30`.
- [ ] **Step 4: Run `scripts/test.sh`.** Expected: all pass.
- [ ] **Step 5: Commit** `feat: rope geometry, thumbnail fit, tilt, fade`

---

### Task 7: System screenshot location and Desktop import

**Files:**
- Create: `Sources/Core/ScreenshotLocation.swift`, `Sources/Core/DesktopImport.swift`
- Test: `Tests/ScreenshotLocationTests.swift`, `Tests/DesktopImportTests.swift`

**Interfaces:**
- Consumes: `LibraryPaths`, `FileOps`, `Day`, `BundleID`, `LibraryScanner`
- Produces:
  - `protocol DefaultsShell { func readLocation() -> String?; func writeLocation(_ path: String); func deleteLocation() }`
  - `struct SystemDefaultsShell: DefaultsShell`. Runs `/usr/bin/defaults read|write|delete com.apple.screencapture location`, then `/usr/bin/killall SystemUIServer` after a write or delete.
  - `final class ScreenshotLocation { init(shell: DefaultsShell, memory: UserDefaults); var isAdopted: Bool { get }; func adopt(_ folder: URL); func restore() }`. Memory keys: `originalScreenshotLocation` (String) and `originalScreenshotLocationWasUnset` (Bool).
  - `enum DesktopImport { static let prefixes = ["截屏", "屏幕快照", "Screenshot", "Screen Shot"]; static func find(in desktop: URL) -> [URL]; static func importAll(_ files: [URL], paths: LibraryPaths, capacity: Int, calendar: Calendar) throws -> [BundleID] }`

- [ ] **Step 1: Write failing tests**

```swift
@Test func adoptRemembersCustomOriginal() { /* fake shell location "/Users/x/Shots" → adopt(lib) → shell holds lib path; restore() → "/Users/x/Shots" */ }
@Test func adoptRemembersUnset() { /* fake shell nil → adopt → restore() calls deleteLocation */ }
@Test func adoptTwiceKeepsFirstOriginal() { /* original "/A"; adopt(lib); adopt(lib) again → restore() → "/A", not lib */ }
@Test func isAdoptedReflectsShell() { /* true only when shell location == lib root path */ }
@Test func findMatchesPrefixesOnly() { /* Desktop with "截屏 1.png", "Screenshot 2.png", "photo.png", "截屏 3.mov" → first two */ }
@Test func importGroupsByDayAndSplitsByCapacity() throws {
  // capacity 2; files: 3 on 11-12, 1 on 11-13 → ids ["2026-11-13 · I", "2026-11-12 · II", "2026-11-12 · I"] (sorted); desktop files gone
}
@Test func importContinuesExistingOrdinals() throws { /* River has "2026-11-12 · I" → importing one 11-12 file creates "2026-11-12 · II" */ }
@Test func importDoesNotOverwrite() throws { /* two files named "截屏 1.png" from different folders into the same bundle → both exist, one renamed "(2)" */ }
```

Use a `FakeShell: DefaultsShell` and `UserDefaults(suiteName: UUID().uuidString)!` in tests.

- [ ] **Step 2: Run `scripts/test.sh`.** Expected: FAIL.
- [ ] **Step 3: Implement.** `importAll` groups by `Day(created)`, sorts within each day by `(created, name)`, chunks by `capacity`, gives each chunk the next ordinal for its day and moves files with `moveUnique` (move, not copy).
- [ ] **Step 4: Run `scripts/test.sh`.** Expected: all pass.
- [ ] **Step 5: Commit** `feat: screenshot location adopt/restore, Desktop import`

---

### Task 8: App model, folder watcher, theme and the rope strip

**Files:**
- Create: `Sources/App/Theme.swift`, `Sources/App/Settings.swift`, `Sources/App/AppModel.swift`, `Sources/App/FolderWatcher.swift`, `Sources/App/ThumbnailCache.swift`, `Sources/App/ShotCard.swift`, `Sources/App/RopeView.swift`, `scripts/seed-demo.sh`
- Modify: `Sources/App/ClotheslineApp.swift` (replace PoC content with the real strips; keep `StripWindow` and `HotKey`)

**Interfaces:**
- Consumes: everything in `Sources/Core`, `StripWindow`, `HotKey`
- Produces:
  - `enum Theme`: static colors and metrics from Global Constraints, plus `static func inscription(_ size: CGFloat) -> Font` (Palatino-Roman, tracking 3) and `static func song(_ size: CGFloat) -> Font`.
  - `final class Settings`: UserDefaults-backed `capacity: Int` (8/12/16, default 12), `paused: Bool`, `hasOnboarded: Bool`, `launchAtLogin: Bool`.
  - `@MainActor final class AppModel: ObservableObject`, which owns the paths, `RopeKeeper`, `LetheQueue` and `ScreenshotLocation`.
    - Published: `snapshot: LibrarySnapshot`, `arriving: Set<URL>`, `expanded: BundleID?`, `isDragging: Bool`, `summoned: Bool`.
    - Methods: `func refresh()`, `func ingest()` (no-op while `settings.paused`), `func sink(_ urls: [URL])`, `func rescue(_ url: URL)`, `func setSummoned(_ on: Bool)`, `func today() -> Day`.
  - `final class FolderWatcher { init(url: URL, onChange: @escaping () -> Void); func start(); func stop() }`. Uses `DispatchSource.makeFileSystemObjectSource` on the root folder with `.write`. Debounce 0.3s, then call `onChange` only once every candidate file's size is unchanged across two reads 0.3s apart.
  - `final class ThumbnailCache { static let shared; func image(for url: URL, size: CGSize) async -> NSImage? }` (`QLThumbnailGenerator`, keyed by url + size).
  - `struct ShotCard: View { let shot: Shot; let size: CGSize; var opacity: Double = 1; var saturation: Double = 1 }`. Draws the 3pt white frame, the shadow and the peg. Interactions are added in Task 9.
  - `struct RopeView: View`. Draws `Labels.today` at (x0, 26 · scale), the curve from `RopeGeometry.path()`, and `ShotCard`s at `layout` slots. New `arriving` shots animate from the screen's bottom-right corner along an arc to their slot over 1.0s with ease-in-out. A cut animates the rope shots shrinking toward the bottom-left over about 2s; implement it as a fade and move.
- Behavior: on launch, run `ensureExists`, `cutIfStale(now:)`, `ingest()`, then `refresh()`. `FolderWatcher` change → `ingest()` → `refresh()`. Also refresh when anything inside `Rope/` or `River/` changes (watch those folders too), so Finder edits show up.
- Debug flag: launching with `--summon` starts summoned. Used for verification screenshots.

- [ ] **Step 1: Write `scripts/seed-demo.sh <root>`.** It creates `Rope/` with 7 images and `River/` bundles for 2026-11-13, 11-12, 11-10, 11-08, 11-05, 11-01 and 10-28. Images are made with `sips -s format png -Z 900` from files in `/System/Library/Desktop Pictures/` and `/System/Applications/*.app/Contents/Resources/AppIcon.icns`.
- [ ] **Step 2: Implement the files above.**
- [ ] **Step 3: Verify with `scripts/build.sh`, `scripts/seed-demo.sh build/demo`, then `CLOTHESLINE_ROOT=$PWD/build/demo ./build/Clothesline --summon &`, `sleep 3`, `screencapture -x build/rope.png`.** Expected: `build/rope.png` shows the line with 7 framed screenshots, pegs and `HODIE · XIV · XI`, matching the sketch. If `screencapture` is blocked by Screen Recording permission, ask the user to grant it to the terminal or to look at the screen and confirm.
- [ ] **Step 4: Verify live catching.** `cp` a png into `build/demo/` while the app runs. Expected: it floats onto the line within about 1.5s and disappears from the root.
- [ ] **Step 5: Run `scripts/test.sh`.** Expected: still all pass.
- [ ] **Step 6: Commit** `feat: app model, folder watcher, rope strip`

---

### Task 9: Screenshot interactions — hover, Quick Look, drag out, context menu

**Files:**
- Create: `Sources/App/QuickLook.swift`
- Modify: `Sources/App/ShotCard.swift`

**Interfaces:**
- Consumes: `AppModel`, `ThumbnailCache`
- Produces:
  - `@MainActor final class QuickLook: NSObject, QLPreviewPanelDataSource { static let shared; func show(_ urls: [URL], index: Int) }`
  - `ShotCard` gains these behaviors:
    - Hover → an about 2× enlarged preview floating near the card (overlay, does not shift the layout).
    - Single click → `QuickLook.shared.show`.
    - Drag → `.onDrag { NSItemProvider(contentsOf: shot.url) }`, setting `model.isDragging` true while dragging. The file stays where it is.
    - Context menu → 快速查看 / 在 Finder 中显示 (`NSWorkspace.activateFileViewerSelecting`) / 拷贝 (file URL + image on `NSPasteboard`) / 沉入忘川 (`model.sink([url])`).
    - If Task 2 found that drag-out fails in desktop mode, also call `model.setSummoned(true)` when a drag starts.

- [ ] **Step 1: Implement.**
- [ ] **Step 2: Verify manually with the demo library and `--summon`.** Hover enlarges; click opens Quick Look; dragging into TextEdit or a chat app inserts the image and the card stays on the line; the context-menu items work.
- [ ] **Step 3: Commit** `feat: screenshot hover, Quick Look, drag out, context menu`

---

### Task 10: The River of Memory

**Files:**
- Create: `Sources/App/RiverView.swift`
- Modify: `Sources/App/ClotheslineApp.swift` (bottom strip hosts `RiverView`; it grows to 360pt tall while a bundle is expanded)

**Interfaces:**
- Consumes: `AppModel.snapshot.river`, `Fade`, `Labels`, `ShotCard`, `Theme`
- Produces: `struct RiverView: View`. Water band 130pt tall: a vertical gradient of `#4f6f8f` going 0 → 16% → 0, plus about 26 short white glints at 15–50% that drift slowly. `ΜΝΗΜΟΣΥΝΗ` sits at the left and `ΛΗΘΗ →` at the right, in `Theme.inscription(11)`.
  - A bundle shows up to 3 `ShotCard`s at 78×52, stacked with offset (7, −5) and rotation (j−1)·2°. Below it is the label from `Labels.bundle(dayHasSeveral:currentYear:)`. Bundles are 190pt apart, newest at the left.
  - Fade per bundle: `Fade.appearance(age: id.day.days(until: model.today()))`, applied as opacity and `.saturation()`.
  - Hover on a bundle: animate to scale 1.28, lift by 24pt, opacity and saturation 1, `#e8c77a` glow with an 8pt blur, and the caption `ἀνάμνησις · 回忆` for 2s. Use the exact caption text from Global Constraints.
  - Scrolling: a horizontal `ScrollView` driven by the wheel or trackpad. Thumbnails load lazily (`LazyHStack`).
  - Click a bundle → `model.expanded = id`. The bundle unrolls above the river into a row of full `ShotCard`s (Thumb.fit sizes) with all Task 9 interactions. `Esc` or a click on empty space collapses it.

- [ ] **Step 1: Implement.**
- [ ] **Step 2: Verify.** Run with the demo library and `--summon`, then `screencapture -x build/river.png`. Expected: seven bundles fading to the right with Roman labels, matching the sketch's light version. Hover and expansion behave as described.
- [ ] **Step 3: Commit** `feat: river of memory with recollection hover and expansion`

---

### Task 11: Lethe in the interface

**Files:**
- Create: `Sources/App/LetheZone.swift`
- Modify: `Sources/App/RiverView.swift`, `Sources/App/ShotCard.swift`, `Sources/App/AppModel.swift`

**Interfaces:**
- Consumes: `LetheQueue`, `Lethe.permanentlyDelete`, `AppModel.isDragging`
- Produces:
  - `struct LetheZone: View`. A dark water patch about 160×110pt at the river's right end, under the `ΛΗΘΗ` label. It fades in only while `model.isDragging`. Its `.onDrop(of: [.fileURL])` calls `model.sink(urls)`.
  - Whole bundles are draggable too: the provider carries every file URL in the bundle.
  - Sinking visual: any `ShotCard` or bundle whose URL is in the queue moves down 40pt and fades to 0 over 5s, with an expanding ripple ellipse. Clicking it, or starting to drag it, calls `model.rescue(url)`, and it animates back.
  - `AppModel` runs a 0.25s timer while the queue is non-empty. It calls `commitDue(now:)`, then `refresh()` when anything was deleted.

- [ ] **Step 1: Implement.**
- [ ] **Step 2: Verify with the demo library.**
  - Drag a screenshot onto `ΛΗΘΗ`: it sinks, and after 5s the file is gone from `build/demo`.
  - Repeat and click it during the sink: it returns and the file still exists.
  - Sink a whole bundle: its folder is gone after 5s.
  - Quit during a sink: the file still exists.
- [ ] **Step 3: Run `scripts/test.sh`.** Expected: all pass.
- [ ] **Step 4: Commit** `feat: Lethe drop zone, sinking and rescue`

---

### Task 12: Menu bar, first launch, timers, packaging

**Files:**
- Create: `Sources/App/MenuBar.swift`, `Sources/App/Onboarding.swift`, `Resources/Info.plist`, `scripts/package.sh`
- Modify: `Sources/App/ClotheslineApp.swift`, `Sources/App/AppModel.swift`

**Interfaces:**
- Consumes: `Settings`, `ScreenshotLocation`, `DesktopImport`, `RopeKeeper.cutIfStale`, `HotKey`
- Produces:
  - `final class MenuBar`: an `NSStatusItem` whose icon is a thin arc drawn as a template image (~16×10pt). Menu items, in order:
    - 召唤晾衣绳 ⌃⌥L
    - 暂停接住截图 / 继续接住截图 — on resume, run `ingest()` so the backlog is hung.
    - 打开截图文件夹
    - 绳长 ▸ 8 / 12 / 16
    - 开机启动 (checkmark) — `SMAppService.mainApp.register()/unregister()`
    - 恢复系统截图位置 / 重新接住截图 — restore calls `ScreenshotLocation.restore()`, stops catching, and leaves the strips visible. Re-catching shows the consent sheet again, then `adopt`.
    - 退出
  - `Onboarding`: one small window in the same visual language (Palatino and Songti, white, the line motif). It shows three lines of copy:
    - 绳 · 今天的截图挂在这里
    - 河 · 过去的截图永远在这里
    - 忘川 · 只有你亲手放进去的才会被遗忘
    - If `docs/poc-notes.md` made summon primary, add a fourth line: 按 ⌃⌥L 召唤.
    - Buttons: 「把截图接到晾衣绳」 → `adopt`. Then a second step: 「桌面上有 N 张旧截图，收进记忆之河？」 with 收进河里 / 暂不 → `DesktopImport.importAll`. Finally set `hasOnboarded`.
  - Timers: subscribe to `NSNotification.Name.NSCalendarDayChanged` and `NSWorkspace.didWakeNotification`, each calling `cutIfStale(now: Date())` then `refresh()`. On launch, enable launch-at-login if `Settings.launchAtLogin` defaults true and it is not yet registered.
  - `Resources/Info.plist` keys:
    - `CFBundleIdentifier` `local.clothesline`
    - `CFBundleName` and `CFBundleDisplayName` `晾衣绳`
    - `CFBundleExecutable` `Clothesline`
    - `CFBundlePackageType` `APPL`
    - `CFBundleShortVersionString` `0.1`
    - `LSUIElement` true
    - `LSMinimumSystemVersion` `26.0`
    - `NSDesktopFolderUsageDescription` 「晾衣绳需要把桌面上的旧截图收进记忆之河。」
  - `scripts/package.sh`: runs `build.sh`; assembles `build/晾衣绳.app/Contents/{MacOS/Clothesline,Info.plist}`; runs `codesign --force -s - build/晾衣绳.app`; replaces `~/Applications/晾衣绳.app`.

- [ ] **Step 1: Implement.**
- [ ] **Step 2: Run `scripts/test.sh`.** Expected: all pass.
- [ ] **Step 3: Run `scripts/package.sh`, then `codesign -dv ~/Applications/晾衣绳.app`.** Expected: `Signature=adhoc`.
- [ ] **Step 4: Ask the user before the first real launch.** This launch changes their screenshot location and may move Desktop files. Then `open ~/Applications/晾衣绳.app` and walk through onboarding together.
  - Verify: `defaults read com.apple.screencapture location` prints the Clothesline root.
  - A real ⌘⇧4 screenshot left undragged hangs on the line.
  - Dragging one from the floating thumbnail leaves the line untouched.
  - 恢复系统截图位置 puts the original value back.
- [ ] **Step 5: Commit** `feat: menu bar, onboarding, midnight/wake cuts, app packaging`

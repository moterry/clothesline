import AppKit
import AVFoundation
import Foundation

// film still <script.json> <zh|en> <seconds> <out.png>
// film video <script.json> <zh|en> <out.mov>
// film mux   <video.mov> <music.wav> <vo-manifest.json> <seconds> <out.mp4>

func loadScript(_ path: String) -> FilmScript {
    try! JSONDecoder().decode(FilmScript.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
}

func makeContext(_ data: UnsafeMutableRawPointer?, bytesPerRow: Int) -> CGContext {
    CGContext(data: data, width: 1920, height: 1080, bitsPerComponent: 8, bytesPerRow: bytesPerRow,
              space: CGColorSpace(name: CGColorSpace.sRGB)!,
              bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
}

func still(_ film: Film, t: Double, out: URL) {
    let ctx = makeContext(nil, bytesPerRow: 0)
    film.render(into: ctx, t: t)
    FakeShots.writePNG(ctx.makeImage()!, to: out)
}

func video(_ film: Film, out: URL, fps: Int32 = 30) throws {
    try? FileManager.default.removeItem(at: out)
    let writer = try AVAssetWriter(outputURL: out, fileType: .mov)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 1920, AVVideoHeightKey: 1080,
        AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 16_000_000,
                                          AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel],
    ])
    input.expectsMediaDataInRealTime = false
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: 1920, kCVPixelBufferHeightKey as String: 1080,
    ])
    writer.add(input)
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)
    let frames = Int(film.script.duration * Double(fps))
    for i in 0..<frames {
        while !input.isReadyForMoreMediaData { usleep(2000) }
        var pb: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pb)
        let buf = pb!
        CVPixelBufferLockBaseAddress(buf, [])
        let ctx = makeContext(CVPixelBufferGetBaseAddress(buf), bytesPerRow: CVPixelBufferGetBytesPerRow(buf))
        film.render(into: ctx, t: Double(i) / Double(fps))
        CVPixelBufferUnlockBaseAddress(buf, [])
        adaptor.append(buf, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: fps))
        if i % 150 == 0 { print("frame \(i)/\(frames)") }
    }
    input.markAsFinished()
    let done = DispatchSemaphore(value: 0)
    writer.finishWriting { done.signal() }
    done.wait()
    if writer.status != .completed { print("writer failed: \(String(describing: writer.error))"); exit(1) }
}

struct VOClip: Decodable { let file: String; let start: Double; let duration: Double }

func mux(video: URL, music: URL, vo: [VOClip], seconds: Double, out: URL) async throws {
    try? FileManager.default.removeItem(at: out)
    let comp = AVMutableComposition()
    let total = CMTime(seconds: seconds, preferredTimescale: 600)

    let vAsset = AVURLAsset(url: video)
    let vTrack = try await vAsset.loadTracks(withMediaType: .video).first!
    let cv = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
    try cv.insertTimeRange(CMTimeRange(start: .zero, duration: total), of: vTrack, at: .zero)

    let mAsset = AVURLAsset(url: music)
    let mTrack = try await mAsset.loadTracks(withMediaType: .audio).first!
    let mDur = try await mAsset.load(.duration)
    let cm = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
    try cm.insertTimeRange(CMTimeRange(start: .zero, duration: CMTimeMinimum(mDur, total)), of: mTrack, at: .zero)

    let cvo = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
    for clip in vo {
        let a = AVURLAsset(url: URL(fileURLWithPath: clip.file))
        let tr = try await a.loadTracks(withMediaType: .audio).first!
        let d = try await a.load(.duration)
        try cvo.insertTimeRange(CMTimeRange(start: .zero, duration: d), of: tr, at: CMTime(seconds: clip.start, preferredTimescale: 600))
    }

    // Music sits under the voice: dip while a line is spoken, rise in the gaps.
    // Build strictly increasing volume keyframes, then ramp between neighbours (ramps must not overlap).
    let high: Float = 0.5, low: Float = 0.26
    var keys: [(Double, Float)] = [(0, high)]
    func key(_ t: Double, _ v: Float) {
        let tt = max(t, (keys.last?.0 ?? 0) + 0.01)
        keys.append((tt, v))
    }
    let clips = vo.sorted { $0.start < $1.start }
    for (i, clip) in clips.enumerated() {
        let end = clip.start + clip.duration
        if keys.last!.1 != low {
            key(clip.start - 0.35, keys.last!.1)
            key(clip.start, low)
        }
        let nextStart = i + 1 < clips.count ? clips[i + 1].start : seconds + 10
        if nextStart - 0.35 - end > 0.6 {
            key(end + 0.05, low)
            key(end + 0.55, high)
        }
    }
    let mp = AVMutableAudioMixInputParameters(track: cm)
    mp.setVolume(high, at: .zero)
    for (a, b) in zip(keys, keys.dropFirst()) where b.0 > a.0 {
        mp.setVolumeRamp(fromStartVolume: a.1, toEndVolume: b.1,
                         timeRange: CMTimeRange(start: CMTime(seconds: a.0, preferredTimescale: 600),
                                                end: CMTime(seconds: b.0, preferredTimescale: 600)))
    }
    let vp = AVMutableAudioMixInputParameters(track: cvo)
    vp.setVolume(0.74, at: .zero)
    let mix = AVMutableAudioMix()
    mix.inputParameters = [mp, vp]

    let export = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality)!
    export.audioMix = mix
    try await export.export(to: out, as: .mp4)
}

let args = CommandLine.arguments
switch args.count > 1 ? args[1] : "" {
case "still":
    still(Film(lang: args[3], script: loadScript(args[2])), t: Double(args[4])!, out: URL(fileURLWithPath: args[5]))
case "video":
    try video(Film(lang: args[3], script: loadScript(args[2])), out: URL(fileURLWithPath: args[4]))
case "mux":
    let clips = try JSONDecoder().decode([VOClip].self, from: Data(contentsOf: URL(fileURLWithPath: args[4])))
    try await mux(video: URL(fileURLWithPath: args[2]), music: URL(fileURLWithPath: args[3]), vo: clips,
                  seconds: Double(args[5])!, out: URL(fileURLWithPath: args[6]))
default:
    print("usage: film still|video|mux …"); exit(1)
}

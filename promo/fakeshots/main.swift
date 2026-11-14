import Foundation

// Usage: fakeshots <out-dir> <count> [seed]
// Writes <count> fake screenshots named 0.png, 1.png, … cycling through every kind.
let args = CommandLine.arguments
guard args.count >= 3, let count = Int(args[2]) else {
    print("usage: fakeshots <out-dir> <count> [seed]"); exit(1)
}
let dir = URL(fileURLWithPath: args[1])
let seed = args.count > 3 ? UInt64(args[3]) ?? 1 : 1
try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
for i in 0..<count {
    let kind = FakeShots.kinds[i % FakeShots.kinds.count]
    FakeShots.writePNG(FakeShots.image(kind, seed: seed &+ UInt64(i) &* 7919), to: dir.appending(path: "\(i).png"))
}

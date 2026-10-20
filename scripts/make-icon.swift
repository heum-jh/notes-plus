// Draws Resources/AppIcon.icns. Run: swift scripts/make-icon.swift
import AppKit

func draw(_ size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = size / 1024
    // macOS icon grid: 824pt body inset 100pt, ~185pt corner radius.
    let body = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let shape = NSBezierPath(roundedRect: body, xRadius: 185 * s, yRadius: 185 * s)
    NSGradient(starting: NSColor(red: 1.0, green: 0.86, blue: 0.35, alpha: 1), ending: NSColor(red: 1.0, green: 0.68, blue: 0.10, alpha: 1))!
        .draw(in: shape, angle: -90)
    // Note lines.
    NSColor.white.withAlphaComponent(0.95).setFill()
    for (i, width) in [560.0, 480.0, 320.0].enumerated() {
        NSBezierPath(roundedRect: NSRect(x: 232 * s, y: (650 - Double(i) * 130) * s, width: width * s, height: 56 * s),
                     xRadius: 28 * s, yRadius: 28 * s).fill()
    }
    // Plus badge.
    let badge = NSRect(x: 600 * s, y: 170 * s, width: 250 * s, height: 250 * s)
    NSColor(red: 0.20, green: 0.16, blue: 0.10, alpha: 1).setFill()
    NSBezierPath(ovalIn: badge).fill()
    NSColor.white.setFill()
    NSBezierPath(roundedRect: NSRect(x: badge.midX - 80 * s, y: badge.midY - 20 * s, width: 160 * s, height: 40 * s), xRadius: 20 * s, yRadius: 20 * s).fill()
    NSBezierPath(roundedRect: NSRect(x: badge.midX - 20 * s, y: badge.midY - 80 * s, width: 40 * s, height: 160 * s), xRadius: 20 * s, yRadius: 20 * s).fill()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appending(path: "AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try! draw(CGFloat(base * scale)).representation(using: .png, properties: [:])!.write(to: iconset.appending(path: name))
    }
}
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", root.appending(path: "Resources/AppIcon.icns").path]
try! task.run()
task.waitUntilExit()
print(task.terminationStatus == 0 ? "Resources/AppIcon.icns" : "iconutil failed")

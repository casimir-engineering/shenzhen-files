// Renders the approved Shenzhen Files macOS app-icon master at any pixel size.
//
// The ImageGen master carries the polished folder artwork. This renderer adds
// a deterministic, antialiased macOS rounded-square mask so stray extraction
// pixels can never escape the icon, and so every iconset size shares exactly
// the same safe bounds.
//
//   swift make-logo.swift <out.png> <pixel-size>
import AppKit

guard CommandLine.arguments.count >= 3, let size = Int(CommandLine.arguments[2]) else {
    FileHandle.standardError.write("usage: make-logo.swift <out.png> <pixel-size>\n".data(using: .utf8)!)
    exit(2)
}

let outputPath = CommandLine.arguments[1]
let canvasSize = CGFloat(size)
let sourceURL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("AppIcon-source-v3.png")

guard let source = NSImage(contentsOf: sourceURL) else {
    FileHandle.standardError.write("failed to load icon master at \(sourceURL.path)\n".data(using: .utf8)!)
    exit(3)
}

let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                              pixelsWide: size,
                              pixelsHigh: size,
                              bitsPerSample: 8,
                              samplesPerPixel: 4,
                              hasAlpha: true,
                              isPlanar: false,
                              colorSpaceName: .deviceRGB,
                              bytesPerRow: 0,
                              bitsPerPixel: 0)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSGraphicsContext.current?.imageInterpolation = .high
NSGraphicsContext.current?.shouldAntialias = true

let canvas = NSRect(x: 0, y: 0, width: canvasSize, height: canvasSize)
NSColor.clear.setFill()
canvas.fill()

// ImageGen correctly extracted alpha but left a few fringe pixels beyond the
// tile. Keep a 5.5% optical margin and clip to a consistent App-style tile.
let inset = canvasSize * 0.055
let tile = canvas.insetBy(dx: inset, dy: inset)
let mask = NSBezierPath(roundedRect: tile,
                        xRadius: canvasSize * 0.205,
                        yRadius: canvasSize * 0.205)
mask.addClip()

source.draw(in: canvas,
            from: NSRect(origin: .zero, size: source.size),
            operation: .sourceOver,
            fraction: 1.0,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high])

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("failed to encode PNG\n".data(using: .utf8)!)
    exit(1)
}
try! png.write(to: URL(fileURLWithPath: outputPath))

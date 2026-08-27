// Renders the approved Shenzhen Files macOS app-icon master at any pixel size.
//
// The ImageGen master carries the polished folder artwork. This renderer crops
// its redundant transparent extraction fringe, then adds a deterministic,
// antialiased macOS rounded-square mask so the tile fills the icon canvas and
// every iconset size shares exactly the same bounds.
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

// The approved master already contains a roughly 5.5% transparent extraction
// fringe. Crop that fringe instead of adding another inset; macOS applies its
// own optical sizing in the Dock, so an inset here made the app icon look tiny.
let sourceInset = min(source.size.width, source.size.height) * 0.055
let sourceCrop = NSRect(x: sourceInset,
                        y: sourceInset,
                        width: source.size.width - (sourceInset * 2),
                        height: source.size.height - (sourceInset * 2))
let mask = NSBezierPath(roundedRect: canvas,
                        xRadius: canvasSize * 0.225,
                        yRadius: canvasSize * 0.225)
mask.addClip()

source.draw(in: canvas,
            from: sourceCrop,
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

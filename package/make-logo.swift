// Generates the Shenzhen Files folder-first logo on a transparent background.
//
// The folder is deliberately the dominant shape so the app remains identifiable
// in a 16 px menu/Dock rendering. The small 深圳 signature keeps the Shenzhen
// product identity without competing with the file-manager metaphor.
//
//   swift make-logo.swift <out.png> <pixel-size>
import AppKit

guard CommandLine.arguments.count >= 3, let size = Int(CommandLine.arguments[2]) else {
    FileHandle.standardError.write("usage: make-logo.swift <out.png> <pixel-size>\n".data(using: .utf8)!)
    exit(2)
}

let outputPath = CommandLine.arguments[1]
let canvasSize = CGFloat(size)

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

// Start with genuinely transparent pixels even if a bitmap implementation
// returns non-zeroed storage.
NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: canvasSize, height: canvasSize).fill()

func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
    NSPoint(x: x * canvasSize, y: y * canvasSize)
}

// A darker rear shell and lighter front flap make the silhouette read as a
// folder, rather than a rounded rectangle, without gradients or fine detail.
let rearBlue = NSColor(calibratedRed: 0.0,
                       green: 92.0 / 255.0,
                       blue: 156.0 / 255.0,
                       alpha: 1.0)
let frontBlue = NSColor(calibratedRed: 5.0 / 255.0,
                        green: 132.0 / 255.0,
                        blue: 197.0 / 255.0,
                        alpha: 1.0)
let signatureWhite = NSColor(calibratedWhite: 1.0, alpha: 0.92)

let rear = NSBezierPath()
rear.move(to: point(0.105, 0.245))
rear.line(to: point(0.105, 0.695))
rear.curve(to: point(0.185, 0.790),
           controlPoint1: point(0.105, 0.750),
           controlPoint2: point(0.140, 0.790))
rear.line(to: point(0.345, 0.790))
rear.curve(to: point(0.430, 0.705),
           controlPoint1: point(0.385, 0.790),
           controlPoint2: point(0.397, 0.705))
rear.line(to: point(0.835, 0.705))
rear.curve(to: point(0.895, 0.645),
           controlPoint1: point(0.870, 0.705),
           controlPoint2: point(0.895, 0.680))
rear.line(to: point(0.895, 0.245))
rear.close()
rearBlue.setFill()
rear.fill()

let front = NSBezierPath()
front.move(to: point(0.165, 0.665))
front.curve(to: point(0.095, 0.585),
            controlPoint1: point(0.125, 0.665),
            controlPoint2: point(0.095, 0.625))
front.line(to: point(0.132, 0.245))
front.curve(to: point(0.225, 0.155),
            controlPoint1: point(0.138, 0.190),
            controlPoint2: point(0.175, 0.155))
front.line(to: point(0.775, 0.155))
front.curve(to: point(0.868, 0.245),
            controlPoint1: point(0.825, 0.155),
            controlPoint2: point(0.862, 0.190))
front.line(to: point(0.905, 0.585))
front.curve(to: point(0.835, 0.665),
            controlPoint1: point(0.905, 0.625),
            controlPoint2: point(0.875, 0.665))
front.close()
frontBlue.setFill()
front.fill()

func firstAvailableFont(names: [String], size: CGFloat) -> NSFont {
    for name in names {
        if let font = NSFont(name: name, size: size) {
            return font
        }
    }
    return NSFont.systemFont(ofSize: size, weight: .semibold)
}

let signature = "深圳" as NSString
let signatureFont = firstAvailableFont(names: ["PingFangSC-Semibold", "PingFangSC-Medium"],
                                       size: canvasSize * 0.125)
let signatureAttributes: [NSAttributedString.Key: Any] = [
    .font: signatureFont,
    .foregroundColor: signatureWhite,
    .kern: -canvasSize * 0.004,
]
let signatureSize = signature.size(withAttributes: signatureAttributes)
signature.draw(at: NSPoint(x: canvasSize * 0.775 - signatureSize.width / 2,
                           y: canvasSize * 0.235),
               withAttributes: signatureAttributes)

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("failed to encode PNG\n".data(using: .utf8)!)
    exit(1)
}
try! png.write(to: URL(fileURLWithPath: outputPath))

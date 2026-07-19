// Generates the Shenzhen Files logo mark: "深圳" in the Shenzhen-product blue
// over a "Files" subtitle, on a transparent background — the same composition
// as shenzhen-pdf's icon mark (gfx/ShenzhenPDF-*.png), with the subtitle
// swapped from "PDF" to "Files".
//
//   swift make-logo.swift <out.png> <pixel-size>
//
// Colors and geometry sampled from ShenzhenPDF-256x256x32.png:
//   深圳  #005C9C, block ~y52-151 of 256 (≈100 px tall, near full width)
//   PDF   #1A2229, block ~y173-213 of 256 (≈40 px caps), gap ≈22 px
import AppKit

guard CommandLine.arguments.count >= 3, let size = Int(CommandLine.arguments[2]) else {
    FileHandle.standardError.write("usage: make-logo.swift <out.png> <pixel-size>\n".data(using: .utf8)!)
    exit(2)
}
let out = CommandLine.arguments[1]
let S = CGFloat(size)

let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                           pixelsWide: size, pixelsHigh: size,
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                           isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let blue = NSColor(calibratedRed: 0.0, green: 92.0 / 255.0, blue: 156.0 / 255.0, alpha: 1.0)
let dark = NSColor(calibratedRed: 26.0 / 255.0, green: 34.0 / 255.0, blue: 41.0 / 255.0, alpha: 1.0)

func font(_ names: [String], _ pt: CGFloat, weight: NSFont.Weight) -> NSFont {
    for n in names {
        if let f = NSFont(name: n, size: pt) { return f }
    }
    return NSFont.systemFont(ofSize: pt, weight: weight)
}

// 深圳: fill the top band. PingFang SC Semibold matches the PDF-product mark.
let hanzi = "深圳" as NSString
let hanziFont = font(["PingFangSC-Semibold"], S * 0.47, weight: .semibold)
let hanziAttrs: [NSAttributedString.Key: Any] = [.font: hanziFont, .foregroundColor: blue]
let hanziSize = hanzi.size(withAttributes: hanziAttrs)

// Subtitle: same dark tone and heavy grotesque weight as the "PDF" line.
let sub = "Files" as NSString
let subFont = font(["HelveticaNeue-Bold", "Helvetica-Bold"], S * 0.215, weight: .bold)
let subAttrs: [NSAttributedString.Key: Any] = [.font: subFont, .foregroundColor: dark]
let subSize = sub.size(withAttributes: subAttrs)

// Vertical layout mirrors the 256-px reference: hanzi block centered in the
// upper region, subtitle below with a ~0.09*S gap, whole group centered.
let gap = S * 0.02
let totalH = hanziSize.height + gap + subSize.height
let groupBottom = (S - totalH) / 2
// Origin is bottom-left: subtitle sits at the bottom of the group.
sub.draw(at: NSPoint(x: (S - subSize.width) / 2, y: groupBottom), withAttributes: subAttrs)
hanzi.draw(at: NSPoint(x: (S - hanziSize.width) / 2, y: groupBottom + subSize.height + gap),
           withAttributes: hanziAttrs)

NSGraphicsContext.restoreGraphicsState()
guard let data = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("failed to encode PNG\n".data(using: .utf8)!)
    exit(1)
}
try! data.write(to: URL(fileURLWithPath: out))

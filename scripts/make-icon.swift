import AppKit

let output = CommandLine.arguments[1]
let iconset = URL(fileURLWithPath: output).appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: Double((hex >> 16) & 255) / 255,
            green: Double((hex >> 8) & 255) / 255,
            blue: Double(hex & 255) / 255, alpha: 1)
}

func render(size: Int, filename: String) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)

    let background = NSBezierPath(roundedRect: NSRect(x: 42, y: 42, width: 940, height: 940),
                                  xRadius: 212, yRadius: 212)
    color(0xFAF8F5).setFill()
    background.fill()

    let tomato = NSBezierPath()
    tomato.move(to: NSPoint(x: 510, y: 732))
    tomato.curve(to: NSPoint(x: 225, y: 488), controlPoint1: NSPoint(x: 294, y: 784), controlPoint2: NSPoint(x: 199, y: 639))
    tomato.curve(to: NSPoint(x: 512, y: 224), controlPoint1: NSPoint(x: 238, y: 333), controlPoint2: NSPoint(x: 346, y: 224))
    tomato.curve(to: NSPoint(x: 799, y: 488), controlPoint1: NSPoint(x: 678, y: 224), controlPoint2: NSPoint(x: 786, y: 333))
    tomato.curve(to: NSPoint(x: 510, y: 732), controlPoint1: NSPoint(x: 825, y: 639), controlPoint2: NSPoint(x: 730, y: 784))
    tomato.close()
    color(0xC7513D).setFill()
    tomato.fill()

    let leaf = NSBezierPath()
    leaf.move(to: NSPoint(x: 505, y: 719))
    leaf.curve(to: NSPoint(x: 690, y: 850), controlPoint1: NSPoint(x: 509, y: 826), controlPoint2: NSPoint(x: 600, y: 857))
    leaf.curve(to: NSPoint(x: 505, y: 719), controlPoint1: NSPoint(x: 690, y: 741), controlPoint2: NSPoint(x: 597, y: 705))
    color(0x426A4B).setFill()
    leaf.fill()

    let stem = NSBezierPath()
    stem.move(to: NSPoint(x: 512, y: 717))
    stem.curve(to: NSPoint(x: 458, y: 813), controlPoint1: NSPoint(x: 506, y: 761), controlPoint2: NSPoint(x: 483, y: 799))
    stem.lineWidth = 29
    stem.lineCapStyle = .round
    color(0x426A4B).setStroke()
    stem.stroke()

    let ring = NSBezierPath(ovalIn: NSRect(x: 365, y: 353, width: 294, height: 294))
    ring.lineWidth = 16
    NSColor.white.withAlphaComponent(0.88).setStroke()
    ring.stroke()
    let hands = NSBezierPath()
    hands.move(to: NSPoint(x: 512, y: 592))
    hands.line(to: NSPoint(x: 512, y: 500))
    hands.line(to: NSPoint(x: 575, y: 457))
    hands.lineWidth = 20
    hands.lineCapStyle = .round
    hands.lineJoinStyle = .round
    hands.stroke()

    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(filename))
}

for points in [16, 32, 128, 256, 512] {
    try render(size: points, filename: "icon_\(points)x\(points).png")
    try render(size: points * 2, filename: "icon_\(points)x\(points)@2x.png")
}

// Write the standard PNG-backed ICNS container directly. This also works in
// managed environments where iconutil's image conversion service is unavailable.
func uint32(_ value: Int) -> Data {
    var bigEndian = UInt32(value).bigEndian
    return withUnsafeBytes(of: &bigEndian) { Data($0) }
}

var chunks = Data()
for (type, filename) in [
    ("icp4", "icon_16x16.png"), ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"), ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"), ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png"), ("ic11", "icon_16x16@2x.png"),
    ("ic12", "icon_32x32@2x.png"), ("ic13", "icon_128x128@2x.png"),
    ("ic14", "icon_256x256@2x.png")
] {
    let png = try Data(contentsOf: iconset.appendingPathComponent(filename))
    chunks.append(Data(type.utf8))
    chunks.append(uint32(png.count + 8))
    chunks.append(png)
}
var icns = Data("icns".utf8)
icns.append(uint32(chunks.count + 8))
icns.append(chunks)
let iconURL = URL(fileURLWithPath: output).appendingPathComponent("AppIcon.icns")
try icns.write(to: iconURL)
guard let icon = NSImage(contentsOf: iconURL), icon.isValid else {
    fatalError("Generated app icon could not be decoded")
}

// Renders AppIcon.icns: a blue→violet rounded square with a white globe and swap arrows.
import AppKit

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // macOS icon grid: 824/1024 body, ~185 corner radius
    let inset = s * 100 / 1024
    let body = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let path = NSBezierPath(roundedRect: body, xRadius: s * 185 / 1024, yRadius: s * 185 / 1024)

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.01)
    shadow.shadowBlurRadius = s * 0.025
    NSGraphicsContext.saveGraphicsState(); shadow.set()
    NSColor.black.setFill(); path.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(colors: [NSColor(srgbRed: 0.16, green: 0.55, blue: 1.0, alpha: 1),
                        NSColor(srgbRed: 0.45, green: 0.25, blue: 0.95, alpha: 1)])!
        .draw(in: path, angle: -60)

    func symbol(_ name: String, _ pt: CGFloat, _ weight: NSFont.Weight, _ color: NSColor) -> NSImage {
        let cfg = NSImage.SymbolConfiguration(pointSize: pt, weight: weight)
            .applying(.init(paletteColors: [color]))
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)!.withSymbolConfiguration(cfg)!
    }
    // Circular swap arrows, then globe in the middle
    let arrows = symbol("arrow.trianglehead.2.clockwise", s * 0.50, .semibold, NSColor.white.withAlphaComponent(0.55))
    let globe = symbol("globe", s * 0.30, .medium, .white)
    for img in [arrows, globe] {
        let r = NSRect(x: (s - img.size.width) / 2, y: (s - img.size.height) / 2, width: img.size.width, height: img.size.height)
        img.draw(in: r)
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let set = "AppIcon.iconset"
try? FileManager.default.removeItem(atPath: set)
try! FileManager.default.createDirectory(atPath: set, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: URL(fileURLWithPath: "\(set)/icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: URL(fileURLWithPath: "\(set)/icon_\(base)x\(base)@2x.png"))
}

import AppKit

let destination = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
var elements = Data()
func bigEndian(_ number: Int) -> Data {
    var value = UInt32(number).bigEndian
    return withUnsafeBytes(of: &value) { Data($0) }
}
for size in [16, 32, 64, 128, 256, 512, 1024] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let scale = CGFloat(size) / 1024
    let transform = AffineTransform(scale: scale)
    (transform as NSAffineTransform).concat()
    NSColor(calibratedRed: 0.10, green: 0.32, blue: 0.70, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 52, y: 52, width: 920, height: 920), xRadius: 210, yRadius: 210).fill()
    for y in [CGFloat(255), 450, 645] {
        let box = NSBezierPath(roundedRect: NSRect(x: 232, y: y, width: 560, height: 146), xRadius: 32, yRadius: 32)
        NSColor.white.setStroke(); box.lineWidth = 18; box.stroke()
        NSColor.white.setFill()
        NSBezierPath(roundedRect: NSRect(x: 280, y: y+63, width: 230, height: 20), xRadius: 10, yRadius: 10).fill()
        NSColor(calibratedRed: 0.57, green: 0.96, blue: 0.77, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 695, y: y+49, width: 48, height: 48)).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    let data = bitmap.representation(using: .png, properties: [:])!
    let tag = [16: "icp4", 32: "icp5", 64: "icp6", 128: "ic07", 256: "ic08", 512: "ic09", 1024: "ic10"][size]!
    elements.append(Data(tag.utf8)); elements.append(bigEndian(data.count + 8)); elements.append(data)
    // iconutil expects both standard and Retina names.
    if size <= 512 { try data.write(to: destination.appendingPathComponent("icon_\(size)x\(size).png")) }
    if size >= 32 { try data.write(to: destination.appendingPathComponent("icon_\(size/2)x\(size/2)@2x.png")) }
}
var icon = Data("icns".utf8)
icon.append(bigEndian(elements.count + 8)); icon.append(elements)
try icon.write(to: destination.deletingLastPathComponent().appendingPathComponent("AppIcon.icns"))

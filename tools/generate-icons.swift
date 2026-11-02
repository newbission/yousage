// Run from the repository root: swift tools/generate-icons.swift
import AppKit
import Foundation

func render(size: Int, appIcon: Bool) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                              isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: CGFloat(size), y: CGFloat(size))
    if appIcon {
        let tile = CGPath(roundedRect: CGRect(x: 0.055, y: 0.055, width: 0.89, height: 0.89),
                          cornerWidth: 0.205, cornerHeight: 0.205, transform: nil)
        context.addPath(tile)
        context.saveGState()
        context.clip()
        let colors = [NSColor(srgbRed: 0.12, green: 0.23, blue: 0.27, alpha: 1).cgColor,
                      NSColor(srgbRed: 0.035, green: 0.07, blue: 0.12, alpha: 1).cgColor] as CFArray
        context.drawLinearGradient(CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!,
                                   start: CGPoint(x: 0, y: 1), end: CGPoint(x: 1, y: 0), options: [])
        context.restoreGState()
    }
    let inset: CGFloat = appIcon ? 0.08 : 0
    context.translateBy(x: inset, y: inset)
    context.scaleBy(x: 1 - inset * 2, y: 1 - inset * 2)
    let mint = NSColor(srgbRed: 0.49, green: 0.94, blue: 0.76, alpha: 1)
    let ink = appIcon ? mint : NSColor.black
    let center = CGPoint(x: 0.5, y: 0.43)
    func point(_ degrees: Double, _ radius: CGFloat) -> CGPoint {
        let angle = degrees * .pi / 180
        return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
    }
    func arc(from: Double, to: Double, color: NSColor) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(0.085)
        context.setLineCap(.round)
        context.addArc(center: center, radius: 0.34, startAngle: from * .pi / 180,
                       endAngle: to * .pi / 180, clockwise: true)
        context.strokePath()
    }
    arc(from: 210, to: -30, color: appIcon ? mint.withAlphaComponent(0.22) : ink)
    if appIcon { arc(from: 210, to: 46, color: mint) }
    context.setStrokeColor((appIcon ? NSColor.white.withAlphaComponent(0.65) : ink).cgColor)
    context.setLineWidth(appIcon ? 0.023 : 0.04)
    for degrees in [180.0, 90.0, 0.0] {
        context.move(to: point(degrees, 0.235))
        context.addLine(to: point(degrees, 0.263))
    }
    context.strokePath()
    context.setStrokeColor((appIcon ? NSColor.white : ink).cgColor)
    context.setLineWidth(0.065)
    context.move(to: center)
    context.addLine(to: point(46, 0.245))
    context.strokePath()
    context.setFillColor((appIcon ? NSColor.white : ink).cgColor)
    context.fillEllipse(in: CGRect(x: center.x - 0.055, y: center.y - 0.055, width: 0.11, height: 0.11))
    context.setStrokeColor(ink.cgColor)
    context.setLineWidth(0.05)
    context.move(to: CGPoint(x: 0.43, y: 0.195))
    context.addLine(to: CGPoint(x: 0.57, y: 0.195))
    context.strokePath()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appending(path: "yoUsage/Assets.xcassets")
var icons: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)@\(scale)x.png"
        try render(size: points * scale, appIcon: true).write(to: root.appending(path: "AppIcon.appiconset/\(name)"))
        icons.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
    }
}
let info: [String: Any] = ["version": 1, "author": "xcode"]
try JSONSerialization.data(withJSONObject: ["images": icons, "info": info], options: [.prettyPrinted, .sortedKeys])
    .write(to: root.appending(path: "AppIcon.appiconset/Contents.json"))
for scale in [1, 2, 3] {
    try render(size: 18 * scale, appIcon: false).write(to: root.appending(path: "MenuBarMark.imageset/mark@\(scale)x.png"))
}
let images = [1, 2, 3].map { ["idiom": "universal", "scale": "\($0)x", "filename": "mark@\($0)x.png"] }
try JSONSerialization.data(withJSONObject: ["images": images, "info": info, "properties": ["template-rendering-intent": "template"]], options: [.prettyPrinted, .sortedKeys])
    .write(to: root.appending(path: "MenuBarMark.imageset/Contents.json"))
try JSONSerialization.data(withJSONObject: ["info": info]).write(to: root.appending(path: "Contents.json"))

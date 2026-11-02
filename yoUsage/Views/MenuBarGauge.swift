import AppKit
import SwiftUI

/// Render the menu item as a non-template image so macOS preserves status colors.
/// The percentage stays neutral for contrast on both light and dark menu bars.
enum MenuBarGauge {
    @MainActor static func image(usedPercent: Double?, preferences: UsageDisplayPreferences,
                                 dark: Bool) -> NSImage {
        let percent = usedPercent.map { preferences.percent(used: $0) }
        let text = percent.map { "\(Int($0.rounded()))%" } ?? "—"
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .medium)
        let textWidth = ceil((text as NSString).size(withAttributes: [.font: font]).width)
        let size = NSSize(width: 24 + textWidth, height: 18)
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
        let image = NSImage(size: size, flipped: true) { rect in
            appearance.performAsCurrentDrawingAppearance {
                func arc(_ fraction: Double) -> NSBezierPath {
                    let path = NSBezierPath()
                    let steps = max(1, Int(ceil(100 * fraction)))
                    for step in 0...steps {
                        let angle = (210 - 240 * fraction * Double(step) / Double(steps)) * .pi / 180
                        let point = NSPoint(x: 10 + 7 * cos(angle), y: 9 - 7 * sin(angle))
                        if step == 0 { path.move(to: point) } else { path.line(to: point) }
                    }
                    path.lineWidth = 2.5
                    path.lineCapStyle = .round
                    return path
                }
                let statusColor = usedPercent.map {
                    NSColor(UsageLevel(usedPercent: $0, preferences: preferences).color)
                }
                (statusColor?.withAlphaComponent(percent == 0 ? 0.6 : 0.25)
                    ?? NSColor.labelColor.withAlphaComponent(0.22)).setStroke()
                arc(1).stroke()
                if let percent, let usedPercent, percent > 0 {
                    NSColor(UsageLevel(usedPercent: usedPercent, preferences: preferences).color).setStroke()
                    arc(percent / 100).stroke()
                }
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font, .foregroundColor: NSColor.labelColor
                ]
                let textHeight = (text as NSString).size(withAttributes: attributes).height
                (text as NSString).draw(at: NSPoint(x: 24, y: (rect.height - textHeight) / 2),
                                       withAttributes: attributes)
            }
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = "yoUsage \(text) \(preferences.label)"
        return image
    }
}

import SwiftUI

enum YoUsageStyle {
    static let accent = Color(red: 0.12, green: 0.65, blue: 0.51)
}

/// A quota dial shared by the app, widget and menu bar brand.
struct YoUsageMark: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ degrees: Double, _ radius: CGFloat) -> CGPoint {
            let angle = degrees * .pi / 180
            return CGPoint(x: rect.minX + (0.5 + radius * cos(angle)) * rect.width,
                           y: rect.minY + (0.57 - radius * sin(angle)) * rect.height)
        }
        var arc = Path()
        for step in 0...120 {
            let p = point(210 - Double(step) * 2, 0.34)
            if step == 0 { arc.move(to: p) } else { arc.addLine(to: p) }
        }
        var result = arc.strokedPath(StrokeStyle(lineWidth: rect.width * 0.085, lineCap: .round))
        var marks = Path()
        for degrees in [180.0, 90.0, 0.0] {
            marks.move(to: point(degrees, 0.235))
            marks.addLine(to: point(degrees, 0.263))
        }
        result.addPath(marks.strokedPath(StrokeStyle(lineWidth: rect.width * 0.04, lineCap: .round)))
        var needle = Path()
        needle.move(to: point(0, 0))
        needle.addLine(to: point(46, 0.245))
        result.addPath(needle.strokedPath(StrokeStyle(lineWidth: rect.width * 0.065, lineCap: .round)))
        result.addEllipse(in: CGRect(x: rect.minX + rect.width * 0.445, y: rect.minY + rect.height * 0.515,
                                     width: rect.width * 0.11, height: rect.height * 0.11))
        var base = Path()
        base.move(to: CGPoint(x: rect.minX + rect.width * 0.43, y: rect.minY + rect.height * 0.805))
        base.addLine(to: CGPoint(x: rect.minX + rect.width * 0.57, y: rect.minY + rect.height * 0.805))
        result.addPath(base.strokedPath(StrokeStyle(lineWidth: rect.width * 0.05, lineCap: .round)))
        return result
    }
}

struct BrandBadge: View {
    var size: CGFloat = 36
    var body: some View {
        YoUsageMark()
            .fill(Color(red: 0.55, green: 0.96, blue: 0.79))
            .padding(size * 0.13)
            .frame(width: size, height: size)
            .background(Color(red: 0.06, green: 0.13, blue: 0.18).gradient,
                        in: .rect(cornerRadius: size * 0.25))
            .accessibilityHidden(true)
    }
}

import SwiftUI

/// 리셋까지 남은 시간을 실시간으로 표시한다. 시스템이 직접 갱신하므로 위젯에서도 동작한다.
struct ResetCountdownText: View {
    let resetDate: Date
    var now: Date = .now

    var body: some View {
        if resetDate > now {
            Text(timerInterval: now...resetDate, countsDown: true)
                .monospacedDigit()
        } else {
            Text("리셋됨")
        }
    }
}

/// 원형 사용률 게이지.
struct UsageRing: View {
    let usedPercent: Double
    var lineWidth: CGFloat = 8

    var body: some View {
        let level = UsageLevel(usedPercent: usedPercent)
        ZStack {
            Circle()
                .stroke(level.color.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(usedPercent / 100, 0), 1))
                .stroke(level.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
    }
}

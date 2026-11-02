import Foundation

/// 한도 하나를 출력용으로 정리한 행.
struct Row {
    var title: String
    var usedPercent: Double
    var resetDate: Date?

    /// 스냅샷 이후 리셋 시각이 지났으면 윈도우가 비워진 것으로 본다.
    func effectivePercent(at now: Date) -> Double {
        if let resetDate, resetDate <= now { return 0 }
        return min(max(usedPercent, 0), 100)
    }

    func countdown(at now: Date) -> String? {
        guard let resetDate, resetDate > now else { return nil }
        let minutes = Int(resetDate.timeIntervalSince(now) / 60)
        switch minutes {
        case ..<60: return "\(max(minutes, 1))m"
        case ..<(24 * 60): return "\(minutes / 60)h\(minutes % 60)m"
        default: return "\(minutes / 1440)d\(minutes % 1440 / 60)h"
        }
    }
}

func rows(for usage: AccountUsage) -> [Row] {
    [Row(title: "5시간", usedPercent: usage.usedPercent, resetDate: usage.resetDate)]
        + usage.additionalLimits.map { Row(title: $0.title, usedPercent: $0.usedPercent, resetDate: $0.resetDate) }
}

/// 앱이 꺼져 있거나 로그아웃 상태면 스냅샷이 갱신되지 않는다. 15분 넘게 지났으면 경과 분을 돌려준다.
func staleMinutes(of snapshot: UsageSnapshot, at now: Date) -> Int? {
    let minutes = Int(now.timeIntervalSince(snapshot.updatedAt) / 60)
    return minutes >= 15 ? minutes : nil
}

struct Style {
    var color: Bool
    var preferences = UsageDisplayPreferences()

    func level(_ text: String, percent: Double) -> String {
        guard color else { return text }
        let code = switch UsageLevel(usedPercent: percent, preferences: preferences) {
        case .comfortable: "32"
        case .caution: "33"
        case .critical: "31"
        }
        return "\u{1B}[\(code)m\(text)\u{1B}[0m"
    }

    func dim(_ text: String) -> String {
        color ? "\u{1B}[2m\(text)\u{1B}[0m" : text
    }
}

/// 한글 등 전각 문자를 2칸으로 계산한 표시 폭.
func displayWidth(_ text: String) -> Int {
    text.unicodeScalars.reduce(0) { $0 + ($1.value >= 0x1100 ? 2 : 1) }
}

func padded(_ text: String, to width: Int) -> String {
    text + String(repeating: " ", count: max(0, width - displayWidth(text)))
}

/// 한 줄 요약. 예) `Claude Code 5h 12%(3h40m) 주 4% │ Codex 5h 0% 주 1%`
func shortSummary(_ snapshot: UsageSnapshot, at now: Date, style: Style) -> String {
    var parts = snapshot.usages.map { usage in
        var text = usage.name
        for (label, row) in zip(["5h", "주"], rows(for: usage).prefix(2)) {
            let percent = row.effectivePercent(at: now)
            text += " \(label) \(style.preferences.label) " + style.level("\(Int(style.preferences.percent(used: percent).rounded()))%", percent: percent)
            if label == "5h", let countdown = row.countdown(at: now) {
                text += style.dim("(\(countdown))")
            }
        }
        return text
    }
    if let minutes = staleMinutes(of: snapshot, at: now) { parts.append("⚠ \(minutes)분 전") }
    return parts.isEmpty ? "yoUsage: 계정 없음" : parts.joined(separator: " │ ")
}

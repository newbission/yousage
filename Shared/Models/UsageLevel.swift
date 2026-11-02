import SwiftUI

/// 사용률에 따른 상태 단계. 게이지 색상과 메뉴바 심볼을 결정한다.
enum UsageLevel: Sendable {
    case comfortable
    case caution
    case critical

    init(usedPercent: Double, preferences: UsageDisplayPreferences = .init()) {
        switch usedPercent {
        case ..<Double(preferences.cautionPercent): self = .comfortable
        case ..<Double(preferences.criticalPercent): self = .caution
        default: self = .critical
        }
    }

    var color: Color {
        switch self {
        case .comfortable: Color(red: 0.12, green: 0.65, blue: 0.51)
        case .caution: Color(red: 0.95, green: 0.67, blue: 0.08)
        case .critical: .red
        }
    }

    var label: String {
        switch self {
        case .comfortable: "여유"
        case .caution: "주의"
        case .critical: "임박"
        }
    }
}

private struct UsageDisplayPreferencesKey: EnvironmentKey {
    static let defaultValue = UsageDisplayPreferences()
}

extension EnvironmentValues {
    var usageDisplayPreferences: UsageDisplayPreferences {
        get { self[UsageDisplayPreferencesKey.self] }
        set { self[UsageDisplayPreferencesKey.self] = newValue }
    }
}

import SwiftUI

@main
struct YoUsageApp: App {
    @State private var manager = UsageManager()

    var body: some Scene {
        MenuBarExtra {
            UsagePopoverView()
                .environment(manager)
                .environment(\.usageDisplayPreferences, manager.displayPreferences)
        } label: {
            MenuBarLabel(usage: manager.activeUsage)
                .environment(\.usageDisplayPreferences, manager.displayPreferences)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(manager)
                .environment(\.usageDisplayPreferences, manager.displayPreferences)
        }
    }
}

/// 메뉴바에 표시되는 게이지 심볼 + 활성 계정의 잔여 쿼터.
struct MenuBarLabel: View {
    @Environment(\.usageDisplayPreferences) private var preferences
    let usage: AccountUsage?

    var body: some View {
        if let usage {
            Image(systemName: symbolName(for: preferences.percent(used: usage.usedPercent)))
            Text(preferences.percent(used: usage.usedPercent) / 100, format: .percent.precision(.fractionLength(0)))
        } else {
            Image(systemName: "sparkles")
        }
    }

    private func symbolName(for remainingPercent: Double) -> String {
        let step = switch remainingPercent {
        case ..<17: 0
        case ..<42: 33
        case ..<59: 50
        case ..<84: 67
        default: 100
        }
        return "gauge.with.dots.needle.\(step)percent"
    }
}

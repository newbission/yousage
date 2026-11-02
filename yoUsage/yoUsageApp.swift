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

/// Live subscription gauge; status colors follow the user's warning thresholds.
struct MenuBarLabel: View {
    @Environment(\.usageDisplayPreferences) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    let usage: AccountUsage?

    var body: some View {
        Image(nsImage: MenuBarGauge.image(usedPercent: usage?.usedPercent,
                                         preferences: preferences, dark: colorScheme == .dark))
            .renderingMode(.original)
            .accessibilityLabel("yoUsage 구독 한도")
            .accessibilityValue(usage.map {
                "\(Int(preferences.percent(used: $0.usedPercent).rounded()))퍼센트 \(preferences.label)"
            } ?? "불러오는 중")
            .help("yoUsage · 구독 한도 · \(preferences.label)")
    }
}

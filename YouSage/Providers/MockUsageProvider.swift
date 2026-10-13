import Foundation

/// SwiftUI 프리뷰·UI 개발용 Mock. 실제 5시간 롤링 윈도우처럼 시간이 지날수록 사용률이 오르고
/// 리셋 시각이 지나면 다시 낮아진다.
struct MockUsageProvider: UsageProvider {
    let kind: ProviderKind

    private static let window: TimeInterval = 5 * 3600

    func fetchUsage(for account: Account) async throws -> AccountUsage {
        // 네트워크 지연 흉내
        try await Task.sleep(for: .milliseconds(.random(in: 250...700)))

        // 계정마다 고정된 시드(0...1)로 윈도우 시작 시각과 소비 패턴을 달리한다.
        let seed = Double(account.id.uuid.0) / 255
        let now = Date.now.timeIntervalSinceReferenceDate
        let offset = seed * Self.window
        let windowStart = ((now - offset) / Self.window).rounded(.down) * Self.window + offset
        let elapsed = (now - windowStart) / Self.window

        let floor = seed * 75
        let weekReset = Date.now.addingTimeInterval((1 + seed * 5) * 86_400)

        return AccountUsage(
            id: account.id,
            name: account.name,
            provider: account.provider,
            email: "\(account.name.lowercased())@example.com",
            plan: kind == .claudeCode ? "Max 5x" : "Plus",
            usedPercent: floor + elapsed * (100 - floor) * 0.8,
            resetDate: Date(timeIntervalSinceReferenceDate: windowStart + Self.window),
            additionalLimits: [
                UsageLimit(id: "weekly", title: "주간", usedPercent: 20 + seed * 60, resetDate: weekReset),
            ]
        )
    }
}

extension Account {
    static let samples: [Account] = [
        Account(id: UUID(uuidString: "26000000-0000-4000-8000-000000000001")!, name: "Personal", provider: .claudeCode),
        Account(id: UUID(uuidString: "99000000-0000-4000-8000-000000000002")!, name: "Work", provider: .claudeCode, configPath: "~/.claude-work"),
        Account(id: UUID(uuidString: "EE000000-0000-4000-8000-000000000003")!, name: "Codex", provider: .codex),
    ]
}

extension UsageManager {
    /// Mock 데이터로 동작하며 실제 설정·위젯 저장소를 건드리지 않는 인스턴스.
    static var preview: UsageManager {
        let defaults = UserDefaults(suiteName: "com.yousage.preview")!
        defaults.removePersistentDomain(forName: "com.yousage.preview")
        defaults.set(try? JSONEncoder().encode(Account.samples), forKey: "accounts")
        return UsageManager(
            providers: ProviderKind.allCases.map(MockUsageProvider.init),
            defaults: defaults,
            sharesWithWidget: false
        )
    }
}

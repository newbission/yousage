import Foundation

/// UI 개발·동작 검증용 Mock. 실제 5시간 롤링 윈도우처럼 시간이 지날수록 사용률이 오르고
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
        let usedPercent = floor + elapsed * (100 - floor) * 0.8

        let capacity = 2_400_000.0
        let consumed = usedPercent / 100 * capacity
        let weights = [0.55 + seed * 0.2, 0.35 - seed * 0.15, 0.10 - seed * 0.05]
        let breakdown = zip(modelNames, weights).map { name, weight in
            ModelUsage(name: name, tokens: Int(consumed * weight))
        }

        return AccountUsage(
            id: account.id,
            name: account.name,
            provider: account.provider,
            usedPercent: usedPercent,
            resetDate: Date(timeIntervalSinceReferenceDate: windowStart + Self.window),
            modelBreakdown: breakdown
        )
    }

    private var modelNames: [String] {
        switch kind {
        case .claudeCode, .anthropic: ["Sonnet", "Opus", "Haiku"]
        case .chatGPT: ["GPT-5", "GPT-5 mini", "o-series"]
        case .gemini: ["Gemini Pro", "Gemini Flash", "Flash-Lite"]
        case .cursor: ["Auto", "Sonnet", "GPT-5"]
        }
    }
}

extension Account {
    /// 실제 계정 등록 UI 가 생기기 전까지 쓰는 기본 계정 목록.
    static let samples: [Account] = [
        Account(id: UUID(uuidString: "26000000-0000-4000-8000-000000000001")!, name: "Personal", provider: .claudeCode),
        Account(id: UUID(uuidString: "99000000-0000-4000-8000-000000000002")!, name: "Work", provider: .anthropic),
        Account(id: UUID(uuidString: "EE000000-0000-4000-8000-000000000003")!, name: "Side Project", provider: .cursor),
    ]
}

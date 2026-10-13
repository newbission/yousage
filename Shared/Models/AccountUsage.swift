import Foundation

/// 지원하는 AI 서비스 종류. 새 서비스를 붙일 때 case 를 추가하고 `UsageProvider` 구현체를 등록한다.
enum ProviderKind: String, Codable, CaseIterable, Sendable {
    case claudeCode
    case anthropic
    case chatGPT
    case gemini
    case cursor

    var displayName: String {
        switch self {
        case .claudeCode: "Claude Code"
        case .anthropic: "Anthropic"
        case .chatGPT: "ChatGPT"
        case .gemini: "Gemini"
        case .cursor: "Cursor"
        }
    }

    var symbolName: String {
        switch self {
        case .claudeCode: "terminal"
        case .anthropic: "sparkles"
        case .chatGPT: "bubble.left.and.bubble.right"
        case .gemini: "diamond"
        case .cursor: "cursorarrow.rays"
        }
    }
}

/// 사용자가 등록한 계정. 같은 서비스에 여러 계정(개인/업무용)을 둘 수 있다.
struct Account: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var provider: ProviderKind
}

/// 모델별 소비량.
struct ModelUsage: Identifiable, Codable, Hashable, Sendable {
    var name: String
    var tokens: Int

    var id: String { name }
}

/// 한 계정의 현재 롤링 윈도우 사용량 스냅샷.
struct AccountUsage: Identifiable, Codable, Hashable, Sendable {
    /// `Account.id` 와 동일.
    let id: UUID
    var name: String
    var provider: ProviderKind
    /// 현재 윈도우에서 소진한 쿼터 (0...100).
    var usedPercent: Double
    /// 윈도우가 리셋되는 시각.
    var resetDate: Date
    var modelBreakdown: [ModelUsage]

    var remainingPercent: Double { 100 - usedPercent }
    var level: UsageLevel { UsageLevel(usedPercent: usedPercent) }
    var totalTokens: Int { modelBreakdown.reduce(0) { $0 + $1.tokens } }

    /// 전체 소비량 중 해당 모델이 차지하는 비율 (0...1).
    func share(of model: ModelUsage) -> Double {
        totalTokens > 0 ? Double(model.tokens) / Double(totalTokens) : 0
    }
}

/// 앱이 저장하고 위젯이 읽는 공유 데이터.
struct UsageSnapshot: Codable, Sendable {
    var usages: [AccountUsage]
    var activeAccountID: UUID?
    var updatedAt: Date

    var activeUsage: AccountUsage? {
        usages.first { $0.id == activeAccountID } ?? usages.first
    }
}

extension AccountUsage {
    /// 위젯 갤러리/placeholder 용 샘플.
    static let placeholder = AccountUsage(
        id: UUID(),
        name: "Personal",
        provider: .claudeCode,
        usedPercent: 22,
        resetDate: .now.addingTimeInterval(3 * 3600 + 12 * 60),
        modelBreakdown: [
            ModelUsage(name: "Sonnet", tokens: 410_000),
            ModelUsage(name: "Opus", tokens: 180_000),
        ]
    )
}

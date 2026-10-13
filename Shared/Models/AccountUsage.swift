import Foundation

/// 지원하는 AI 서비스 종류. 새 서비스를 붙일 때 case 를 추가하고 `UsageProvider` 구현체를 등록한다.
enum ProviderKind: String, Codable, CaseIterable, Sendable {
    case claudeCode
    case codex

    var displayName: String {
        switch self {
        case .claudeCode: "Claude Code"
        case .codex: "Codex"
        }
    }

    var symbolName: String {
        switch self {
        case .claudeCode: "terminal"
        case .codex: "chevron.left.forwardslash.chevron.right"
        }
    }

    /// CLI 가 로그인 정보를 두는 기본 폴더 (`CLAUDE_CONFIG_DIR` / `CODEX_HOME` 의 기본값).
    var defaultConfigPath: String {
        switch self {
        case .claudeCode: "~/.claude"
        case .codex: "~/.codex"
        }
    }

    var dashboardURL: URL {
        switch self {
        case .claudeCode: URL(string: "https://claude.ai/settings/usage")!
        case .codex: URL(string: "https://chatgpt.com/codex/settings/usage")!
        }
    }
}

/// 사용자가 등록한 계정. 계정 하나는 "CLI 설정 폴더 하나"에 대응한다.
struct Account: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var provider: ProviderKind
    /// CLI 설정 폴더의 절대 경로. `nil` 이면 서비스 기본 폴더.
    var configPath: String?

    var configDirectory: URL {
        let path = configPath ?? provider.defaultConfigPath
        return URL(fileURLWithPath: NSString(string: path).expandingTildeInPath, isDirectory: true)
    }
}

/// 5시간 세션 외의 추가 한도 (주간, 모델별 주간 등).
struct UsageLimit: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var title: String
    /// 0...100
    var usedPercent: Double
    var resetDate: Date?
}

/// 한 계정의 현재 사용량 스냅샷.
struct AccountUsage: Identifiable, Codable, Hashable, Sendable {
    /// `Account.id` 와 동일.
    let id: UUID
    var name: String
    var provider: ProviderKind
    var email: String?
    var plan: String?
    /// 5시간 롤링 윈도우에서 소진한 쿼터 (0...100).
    var usedPercent: Double
    /// 5시간 윈도우가 리셋되는 시각. 윈도우가 아직 시작되지 않았으면 `nil`.
    var resetDate: Date?
    var additionalLimits: [UsageLimit]

    var remainingPercent: Double { 100 - usedPercent }
    var level: UsageLevel { UsageLevel(usedPercent: usedPercent) }
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
        email: nil,
        plan: "Max",
        usedPercent: 22,
        resetDate: .now.addingTimeInterval(3 * 3600 + 12 * 60),
        additionalLimits: []
    )
}

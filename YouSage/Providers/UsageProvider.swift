import Foundation

/// 서비스별 사용량 조회 인터페이스.
///
/// 새 서비스를 붙이려면 이 프로토콜을 구현하고 `UsageManager(providers:)` 에 주입한다.
/// 예) `~/.claude/` 의 CLI 인증 정보를 읽어 사용량 API 를 호출하는 `ClaudeCodeProvider`.
protocol UsageProvider: Sendable {
    var kind: ProviderKind { get }
    func fetchUsage(for account: Account) async throws -> AccountUsage
}

enum UsageError: LocalizedError {
    case unsupportedProvider(ProviderKind)
    case notAuthenticated
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unsupportedProvider(let kind): "\(kind.displayName) 는 아직 지원하지 않습니다."
        case .notAuthenticated: "로그인 정보가 없습니다."
        case .invalidResponse: "응답을 해석할 수 없습니다."
        }
    }
}

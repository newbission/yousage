import CryptoKit
import Foundation

/// Claude Code CLI 가 저장해 둔 OAuth 토큰으로 Anthropic 사용량 API 를 직접 호출한다.
///
/// 1. 키체인(`Claude Code-credentials`)에서 액세스 토큰을 읽는다. 읽기 전용이며 토큰을 갱신·수정하지 않는다.
/// 2. `GET https://api.anthropic.com/api/oauth/usage` 를 호출한다 (Claude Code 의 `/usage` 와 같은 데이터).
/// 3. `five_hour`, `seven_day` 등의 사용률과 리셋 시각을 `AccountUsage` 로 변환한다.
struct ClaudeCodeProvider: UsageProvider {
    let kind = ProviderKind.claudeCode

    private static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private static let keychainService = "Claude Code-credentials"
    private static let loginHint = "터미널에서 Claude Code 를 한 번 실행하면 갱신됩니다."

    func fetchUsage(for account: Account) async throws -> AccountUsage {
        let credentials = try await loadCredentials(for: account)

        var request = URLRequest(url: Self.usageURL)
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        let data = try await URLSession.shared.usageData(for: request, provider: kind, expiredHint: Self.loginHint)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let limits = (try? decoder.decode(LimitsResponse.self, from: data))?.limits ?? []
        let windows = try? decoder.decode(WindowsResponse.self, from: data)

        var usage = AccountUsage(
            id: account.id,
            name: account.name,
            provider: kind,
            email: loadEmail(for: account),
            plan: credentials.planName,
            usedPercent: 0,
            resetDate: nil,
            additionalLimits: []
        )

        if let session = limits.first(where: { $0.kind == "session" }) {
            // 최신 형식: `limits` 배열에 세션·주간·모델별 주간 한도가 모두 들어 있다.
            usage.usedPercent = session.percent
            usage.resetDate = session.resetDate
            usage.additionalLimits = limits.enumerated().compactMap { index, limit in
                guard limit.kind != "session" else { return nil }
                return UsageLimit(id: "\(index)-\(limit.kind)", title: limit.title, usedPercent: limit.percent, resetDate: limit.resetDate)
            }
        } else if let windows, let session = windows.fiveHour {
            // 구 형식: 최상위 `five_hour` / `seven_day` 키.
            usage.usedPercent = session.utilization ?? 0
            usage.resetDate = session.resetDate
            if let weekly = windows.sevenDay, let used = weekly.utilization {
                usage.additionalLimits = [UsageLimit(id: "seven_day", title: "주간", usedPercent: used, resetDate: weekly.resetDate)]
            }
        } else {
            throw UsageError.invalidResponse
        }
        return usage
    }

    // MARK: - Credentials

    private func loadCredentials(for account: Account) async throws -> Credentials {
        // macOS 에서는 키체인, 그 외(또는 키체인을 못 쓰는 환경)에서는 설정 폴더의 파일에 저장된다.
        let keychain = await runProcess(
            "/usr/bin/security",
            arguments: ["find-generic-password", "-s", keychainService(for: account), "-w"]
        )
        let file = try? Data(contentsOf: account.configDirectory.appending(path: ".credentials.json"))

        for data in [keychain, file].compactMap({ $0 }) {
            if let credentials = try? JSONDecoder().decode(CredentialsFile.self, from: data).claudeAiOauth {
                return credentials
            }
        }
        throw UsageError.notAuthenticated("Claude Code 에서 /login 으로 로그인해 주세요.")
    }

    /// 기본 폴더가 아닌 `CLAUDE_CONFIG_DIR` 로 로그인하면 폴더 경로 해시가 서비스 이름 뒤에 붙는다.
    private func keychainService(for account: Account) -> String {
        guard account.configPath != nil else { return Self.keychainService }
        let digest = SHA256.hash(data: Data(account.configDirectory.path.utf8))
        let suffix = digest.prefix(4).map { String(format: "%02x", $0) }.joined()
        return "\(Self.keychainService)-\(suffix)"
    }

    /// 계정 이메일은 CLI 설정 파일(`.claude.json`)에 있다. 기본 폴더일 때는 홈 디렉터리에 놓인다.
    private func loadEmail(for account: Account) -> String? {
        let directory = account.configPath == nil
            ? FileManager.default.homeDirectoryForCurrentUser
            : account.configDirectory
        guard let data = try? Data(contentsOf: directory.appending(path: ".claude.json")) else { return nil }
        return try? JSONDecoder().decode(ConfigFile.self, from: data).oauthAccount?.emailAddress
    }
}

private struct CredentialsFile: Decodable {
    var claudeAiOauth: Credentials?
}

private struct Credentials: Decodable {
    var accessToken: String
    var subscriptionType: String?
    var rateLimitTier: String?

    /// 예) subscriptionType "max" + rateLimitTier "default_claude_max_20x" → "Max 20x"
    var planName: String? {
        guard let subscriptionType else { return nil }
        let multiplier = rateLimitTier?.firstMatch(of: /\d+x/).map { " \($0.output)" } ?? ""
        return subscriptionType.capitalized + multiplier
    }
}

private struct ConfigFile: Decodable {
    struct OAuthAccount: Decodable {
        var emailAddress: String?
    }

    var oauthAccount: OAuthAccount?
}

private struct LimitsResponse: Decodable {
    struct Limit: Decodable {
        struct Scope: Decodable {
            struct Model: Decodable {
                var displayName: String?
            }

            var model: Model?
        }

        /// "session", "weekly_all", "weekly_scoped" …
        var kind: String
        /// 0...100
        var percent: Double
        var resetsAt: String?
        var scope: Scope?

        var resetDate: Date? { resetsAt.flatMap(parseISO8601) }

        var title: String {
            let base = kind.hasPrefix("weekly") ? "주간" : kind.replacing("_", with: " ").capitalized
            guard let model = scope?.model?.displayName else { return base }
            return "\(base) · \(model)"
        }
    }

    var limits: [Limit]
}

private struct WindowsResponse: Decodable {
    struct Window: Decodable {
        /// 0...100
        var utilization: Double?
        var resetsAt: String?

        var resetDate: Date? { resetsAt.flatMap(parseISO8601) }
    }

    var fiveHour: Window?
    var sevenDay: Window?
}

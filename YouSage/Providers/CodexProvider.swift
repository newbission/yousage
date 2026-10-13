import Foundation

/// Codex CLI 가 저장해 둔 ChatGPT 로그인 토큰으로 ChatGPT 사용량 API 를 직접 호출한다.
///
/// 1. `<CODEX_HOME>/auth.json` 에서 액세스 토큰과 계정 ID 를 읽는다. 읽기 전용이며 토큰을 갱신·수정하지 않는다.
/// 2. `GET https://chatgpt.com/backend-api/wham/usage` 를 호출한다 (Codex 의 `/status` 와 같은 데이터).
/// 3. `primary_window`(5시간), `secondary_window`(주간) 사용률을 `AccountUsage` 로 변환한다.
struct CodexProvider: UsageProvider {
    let kind = ProviderKind.codex

    private static let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
    private static let loginHint = "터미널에서 codex 를 한 번 실행하면 갱신됩니다."

    func fetchUsage(for account: Account) async throws -> AccountUsage {
        let authURL = account.configDirectory.appending(path: "auth.json")
        guard let authData = try? Data(contentsOf: authURL),
              let tokens = try? JSONDecoder().decode(AuthFile.self, from: authData).tokens
        else {
            throw UsageError.notAuthenticated("터미널에서 `codex login` 으로 ChatGPT 계정에 로그인해 주세요.")
        }

        var request = URLRequest(url: Self.usageURL)
        request.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
        if let accountID = tokens.accountID {
            request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        }
        let data = try await URLSession.shared.usageData(for: request, provider: kind, expiredHint: Self.loginHint)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let response = try? decoder.decode(UsageResponse.self, from: data),
              let rateLimit = response.rateLimit
        else {
            throw UsageError.invalidResponse
        }

        let claims = tokens.idToken.flatMap(IDTokenClaims.init(jwt:))
        return AccountUsage(
            id: account.id,
            name: account.name,
            provider: kind,
            email: response.email ?? claims?.email,
            plan: response.planType?.capitalized,
            usedPercent: rateLimit.primaryWindow?.usedPercent ?? 0,
            resetDate: rateLimit.primaryWindow?.resetDate,
            additionalLimits: rateLimit.secondaryWindow.map {
                [UsageLimit(id: "secondary", title: "주간", usedPercent: $0.usedPercent, resetDate: $0.resetDate)]
            } ?? []
        )
    }
}

private struct AuthFile: Decodable {
    struct Tokens: Decodable {
        var accessToken: String
        var accountID: String?
        var idToken: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case accountID = "account_id"
            case idToken = "id_token"
        }
    }

    /// API 키로만 로그인한 경우 `nil`. 이때는 구독 한도 자체가 없다.
    var tokens: Tokens?
}

private struct IDTokenClaims: Decodable {
    var email: String?

    /// JWT 의 payload(두 번째 조각)만 디코딩한다. 서명은 검증하지 않는다(표시용).
    init?(jwt: String) {
        let segments = jwt.split(separator: ".")
        guard segments.count >= 2 else { return nil }
        var base64 = String(segments[1]).replacing("-", with: "+").replacing("_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64),
              let claims = try? JSONDecoder().decode(Self.self, from: data)
        else { return nil }
        self = claims
    }
}

private struct UsageResponse: Decodable {
    struct RateLimit: Decodable {
        var primaryWindow: Window?
        var secondaryWindow: Window?
    }

    struct Window: Decodable {
        /// 0...100
        var usedPercent: Double
        /// Unix epoch (초)
        var resetAt: Double?
        var resetAfterSeconds: Double?

        var resetDate: Date? {
            resetAt.map(Date.init(timeIntervalSince1970:))
                ?? resetAfterSeconds.map(Date.now.addingTimeInterval)
        }
    }

    var email: String?
    var planType: String?
    var rateLimit: RateLimit?
}

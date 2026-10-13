import Foundation

/// 서비스별 사용량 조회 인터페이스.
///
/// 새 서비스를 붙이려면 `ProviderKind` 에 case 를 추가하고 이 프로토콜을 구현해
/// `UsageManager(providers:)` 에 주입한다.
protocol UsageProvider: Sendable {
    var kind: ProviderKind { get }
    func fetchUsage(for account: Account) async throws -> AccountUsage
}

enum UsageError: LocalizedError {
    case unsupportedProvider(ProviderKind)
    /// 로그인 정보를 찾지 못함. 연관값은 해결 방법 안내.
    case notAuthenticated(String)
    /// 토큰이 만료됨. 연관값은 해결 방법 안내.
    case tokenExpired(String)
    case http(Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unsupportedProvider(let kind): "\(kind.displayName) 는 아직 지원하지 않습니다."
        case .notAuthenticated(let hint): "로그인 정보를 찾을 수 없습니다. \(hint)"
        case .tokenExpired(let hint): "토큰이 만료되었습니다. \(hint)"
        case .http(let status): "사용량 서버가 오류를 반환했습니다 (HTTP \(status))."
        case .invalidResponse: "응답을 해석할 수 없습니다."
        }
    }
}

extension URLSession {
    /// 사용량 API 를 호출하고 본문을 돌려준다. 401 은 토큰 만료로 취급한다.
    func usageData(for request: URLRequest, provider: ProviderKind, expiredHint: String) async throws -> Data {
        var request = request
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await data(for: request)
        guard let http = response as? HTTPURLResponse else { throw UsageError.invalidResponse }
        Diagnostics.record("\(provider.rawValue)-usage-response", "HTTP \(http.statusCode)\n" + String(decoding: data, as: UTF8.self))
        switch http.statusCode {
        case 200..<300: return data
        case 401: throw UsageError.tokenExpired(expiredHint)
        default: throw UsageError.http(http.statusCode)
        }
    }
}

/// 소수 초 자릿수와 무관하게 ISO 8601 시각을 해석한다.
func parseISO8601(_ string: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: string.replacing(/\.\d+/, with: ""))
}

/// 외부 명령을 실행하고 표준 출력을 돌려준다. 종료 코드가 0 이 아니면 `nil`.
func runProcess(_ executable: String, arguments: [String]) async -> Data? {
    await withCheckedContinuation { continuation in
        DispatchQueue.global(qos: .utility).async {
            let process = Process()
            let stdout = Pipe()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = stdout
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                let data = stdout.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                continuation.resume(returning: process.terminationStatus == 0 ? data : nil)
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
}

/// 문제 해결용 기록. 서비스가 응답 형식을 바꿨을 때 원인을 확인할 수 있도록
/// 마지막 응답 본문(사용률 수치만 담겨 있고 토큰은 없다)과 오류를 `~/Library/Logs/yoUsage/` 에 남긴다.
enum Diagnostics {
    static let directory = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Logs/yoUsage")

    static func record(_ name: String, _ text: String) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let stamped = "\(Date.now.formatted(.iso8601))\n\(text)\n"
        try? stamped.write(to: directory.appending(path: "\(name).txt"), atomically: true, encoding: .utf8)
    }
}

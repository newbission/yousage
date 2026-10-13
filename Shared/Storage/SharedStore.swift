import Foundation

enum AppGroup {
    /// Info.plist 의 `AppGroupIdentifier` (빌드 설정 `APP_GROUP_ID`) 에서 읽는다.
    static let identifier = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String
        ?? "com.yousage.shared"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}

/// 메인 앱과 위젯이 함께 쓰는 App Group 컨테이너 내 JSON 저장소.
enum SharedStore {
    enum StoreError: Error {
        case containerUnavailable
    }

    private static var snapshotURL: URL? {
        AppGroup.containerURL?.appending(path: "usage-snapshot.json")
    }

    static func save(_ snapshot: UsageSnapshot) throws {
        guard let url = snapshotURL else { throw StoreError.containerUnavailable }
        try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
    }

    static func load() -> UsageSnapshot? {
        guard let url = snapshotURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(UsageSnapshot.self, from: data)
    }
}

import Foundation

enum AppGroup {
    /// Info.plist 의 `AppGroupIdentifier` (빌드 설정 `APP_GROUP_ID`) 에서 읽는다.
    static let identifier = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String
        ?? "com.yousage.shared"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}

/// 메인 앱이 쓰고 위젯이 읽는 JSON 스냅샷 저장소.
///
/// 기본은 App Group 컨테이너다. 다만 Team 없이 ad-hoc 서명한 빌드에서는 샌드박스 밖의 앱이
/// 그룹 컨테이너에 쓸 수 없으므로(EPERM), 그때는 `~/Library/Application Support/YouSage/` 에 쓴다.
/// 위젯은 이 폴더에 대한 읽기 전용 샌드박스 예외를 갖고 있고, 두 위치 중 더 최신인 쪽을 읽는다.
enum SharedStore {
    private static let fileName = "usage-snapshot.json"

    private static var groupURL: URL? {
        AppGroup.containerURL?.appending(path: fileName)
    }

    /// 샌드박스 안(위젯)에서도 컨테이너가 아닌 실제 홈 폴더를 가리키도록 passwd 에서 읽는다.
    private static var fallbackURL: URL? {
        guard let home = getpwuid(getuid())?.pointee.pw_dir else { return nil }
        return URL(fileURLWithPath: String(cString: home), isDirectory: true)
            .appending(path: "Library/Application Support/YouSage/\(fileName)")
    }

    static func save(_ snapshot: UsageSnapshot) throws {
        let data = try JSONEncoder().encode(snapshot)
        if let groupURL, (try? data.write(to: groupURL, options: .atomic)) != nil { return }
        guard let fallbackURL else { throw CocoaError(.fileWriteNoPermission) }
        try FileManager.default.createDirectory(at: fallbackURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fallbackURL, options: .atomic)
    }

    static func load() -> UsageSnapshot? {
        [groupURL, fallbackURL]
            .compactMap { $0 }
            .compactMap { try? Data(contentsOf: $0) }
            .compactMap { try? JSONDecoder().decode(UsageSnapshot.self, from: $0) }
            .max { $0.updatedAt < $1.updatedAt }
    }
}

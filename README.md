# YouSage

Claude Code 를 비롯한 AI 계정의 세션 쿼터(5시간 롤링 윈도우), 사용량, 리셋 타이머를 메뉴바와 위젯에서 보여주는 macOS 유틸리티.

> 현재는 Mock 데이터로 동작한다. 실제 조회는 `UsageProvider` 구현체를 추가해 주입하면 된다.

## 요구 사항

- macOS 26 이상, Xcode 26 이상
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## 빌드 & 실행

```sh
xcodegen generate          # project.yml → YouSage.xcodeproj (Info.plist, entitlements 도 함께 생성)
open YouSage.xcodeproj     # YouSage 스킴 선택 후 ⌘R
```

CLI 로만 빌드하려면:

```sh
xcodebuild -project YouSage.xcodeproj -scheme YouSage -derivedDataPath build build
open build/Build/Products/Debug/YouSage.app
```

실행하면 Dock 아이콘 없이 메뉴바에 게이지 아이콘과 잔여 쿼터(예: `85%`)가 나타난다.
메뉴바 항목이 많아 가려진다면 다른 항목을 ⌘-드래그로 정리한다.

위젯은 앱을 한 번 실행한 뒤 바탕화면 우클릭 → **위젯 편집** → "YouSage" 에서 추가한다.

## 프로젝트 구조

```
project.yml                  XcodeGen 정의 (타깃, 서명, Info.plist, entitlements)
Shared/                      앱·위젯 양쪽 타깃에 포함
  Models/AccountUsage.swift    ProviderKind, Account, AccountUsage, UsageSnapshot
  Models/UsageLevel.swift      여유/주의/임박 단계와 색상
  Storage/SharedStore.swift    App Group 컨테이너의 JSON 스냅샷 저장소
  Views/UsageViews.swift       ResetCountdownText, UsageRing
YouSage/                     메뉴바 앱
  YouSageApp.swift             MenuBarExtra(.window) + Settings
  UsageManager.swift           @Observable 상태, 자동 폴링, 위젯 스냅샷 발행
  Providers/                   UsageProvider 프로토콜, MockUsageProvider
  Views/                       UsagePopoverView, AccountCardView, SettingsView
YouSageWidget/               WidgetKit 확장 (systemSmall)
```

## 설정 가이드

모든 설정은 `project.yml` 에 있고 `xcodegen generate` 가 plist/entitlements 를 만들어 준다.

| 항목 | 값 | 위치 |
| --- | --- | --- |
| Deployment Target | macOS 26.0 | `options.deploymentTarget` |
| Swift 언어 모드 | 6 (strict concurrency) | `SWIFT_VERSION` |
| Dock 아이콘 숨김 | `LSUIElement = YES` | 앱 Info.plist |
| 위젯 확장 포인트 | `com.apple.widgetkit-extension` | 위젯 Info.plist |
| App Sandbox | 앱·위젯 모두 켜짐 (위젯은 필수) | entitlements |
| 네트워크 | `com.apple.security.network.client` (앱) | entitlements |
| App Group | `$(TeamIdentifierPrefix)com.yousage.shared` | `APP_GROUP_ID` |

### 서명과 App Group

- 기본값은 Team 없이 ad-hoc 서명("Sign to Run Locally")이라 Apple 계정 없이도 빌드·실행된다.
- 배포하거나 위젯 데이터 공유가 동작하지 않으면 `project.yml` 의 `DEVELOPMENT_TEAM` 에 Team ID 를 넣고
  `xcodegen generate` 를 다시 실행한다. App Group ID 가 `<TeamID>.com.yousage.shared` 로 바뀌며,
  코드에서는 Info.plist 의 `AppGroupIdentifier` 로 읽으므로 수정할 곳은 없다.
- iOS 스타일 `group.` 접두사 ID 는 프로비저닝 프로파일이 필요하므로 쓰지 않는다.

### 실제 데이터 연동 시

`~/.claude/` 를 읽는 Provider 를 추가하려면 샌드박스 예외가 필요하다. 앱 entitlements 에 추가:

```yaml
com.apple.security.temporary-exception.files.home-relative-path.read-only:
  - /.claude/
```

(Mac App Store 배포 시에는 이 예외가 허용되지 않으므로 파일 선택 + security-scoped bookmark 로 대체한다.)

## Provider 추가하기

```swift
struct ClaudeCodeProvider: UsageProvider {
    let kind = ProviderKind.claudeCode

    func fetchUsage(for account: Account) async throws -> AccountUsage {
        // 인증 정보 로드 → 사용량 조회 → AccountUsage 로 변환
    }
}

// YouSageApp.swift
@State private var manager = UsageManager(
    accounts: [...],
    providers: [ClaudeCodeProvider(), MockUsageProvider(kind: .cursor)]
)
```

새 서비스는 `ProviderKind` 에 case 를 추가한 뒤 같은 방식으로 등록한다.

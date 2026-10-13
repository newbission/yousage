# yoUsage

Claude Code 를 비롯한 AI 계정의 세션 쿼터(5시간 롤링 윈도우), 사용량, 리셋 타이머를 메뉴바와 위젯에서 보여주는 macOS 유틸리티.

지원 서비스: **Claude Code**, **Codex (ChatGPT)**

## 사용량을 가져오는 방식

**각 서비스의 사용량 API 를 앱이 직접 호출한다.** 로컬 로그 파일을 집계하거나 웹 페이지를 긁는 방식이 아니다.
로그인은 yoUsage 가 하지 않고, 이미 로그인된 CLI 가 이 Mac 에 저장해 둔 토큰을 **읽기 전용**으로 빌려 쓴다.

```
CLI 로그인 정보 (키체인 / auth.json)
        │  ① 액세스 토큰 읽기 (읽기 전용)
        ▼
     yoUsage ──② HTTPS GET──▶ 서비스 사용량 API
        │  ③ 사용률(%)·리셋 시각 → 메뉴바 / 팝오버 / 위젯
```

| | Claude Code | Codex (ChatGPT) |
| --- | --- | --- |
| ① 토큰 위치 | macOS 키체인 `Claude Code-credentials` (`/usr/bin/security` 로 읽음). 없으면 `<설정 폴더>/.credentials.json` | `<설정 폴더>/auth.json` |
| ② 호출 API | `GET https://api.anthropic.com/api/oauth/usage` | `GET https://chatgpt.com/backend-api/wham/usage` |
| 인증 헤더 | `Authorization: Bearer <토큰>`, `anthropic-beta: oauth-2025-04-20` | `Authorization: Bearer <토큰>`, `ChatGPT-Account-Id` |
| ③ 쓰는 값 | `limits[]` 의 `kind`(session / weekly_all / weekly_scoped), `percent`, `resets_at`, `scope.model.display_name`. 없으면 구 형식 `five_hour` / `seven_day` 의 `utilization` | `rate_limit.primary_window`(5시간), `secondary_window`(주간) 의 `used_percent`, `reset_at` |
| 계정 표시 | 이메일: `.claude.json`, 플랜: 로그인 정보의 `subscriptionType` | 이메일: `id_token`, 플랜: 응답의 `plan_type` |
| 구현 | `yoUsage/Providers/ClaudeCodeProvider.swift` | `yoUsage/Providers/CodexProvider.swift` |

알아둘 점:

- **CLI 가 화면에 보여주는 것과 같은 데이터다.** Claude Code 의 `/usage`, Codex 의 `/status` 가 쓰는 API 를 그대로 호출한다.
  단, 둘 다 공식 문서에 없는 내부 API 라 예고 없이 바뀔 수 있다.
- **토큰은 읽기만 한다.** 갱신하거나 다른 곳에 저장·전송하지 않는다. 토큰이 만료되면 카드에 안내가 뜨고,
  해당 CLI 를 한 번 실행하면 CLI 가 스스로 갱신한다.
- **요청은 해당 서비스 서버로만 간다.** 폴링 주기(기본 3분)마다 계정당 GET 1회.
- 모델별 토큰 수는 API 가 주지 않는다. 대신 주간 한도와 (Claude 의 경우) 모델별 주간 한도를 보여준다.

### 문제 해결

값이 이상하거나 한도 행이 빠지면 `~/Library/Logs/yoUsage/` 를 본다. 서비스별 마지막 응답 본문
(`claudeCode-usage-response.txt`, `codex-usage-response.txt` — 사용률 수치와 계정 이메일이 들어 있고 토큰은 없다)과
위젯 저장 오류가 기록된다. 서비스가 응답 형식을 바꿨다면 이 파일과 Provider 의 디코딩 구조체를 비교하면 된다.

## 다중 계정

**계정 하나 = CLI 설정 폴더 하나.** Claude Code 와 Codex 모두 한 설정 폴더에 한 계정만 로그인되므로,
두 번째 계정은 다른 폴더에 로그인해 두고 그 폴더를 yoUsage 에 등록한다.

```sh
# Claude Code 업무용 계정
CLAUDE_CONFIG_DIR=~/.claude-work claude      # 실행 후 /login

# Codex 업무용 계정
CODEX_HOME=~/.codex-work codex login
```

그다음 **설정 → 연결된 계정 → 계정 추가 → 다른 설정 폴더 선택…** 에서 그 폴더를 고른다.
(숨김 폴더는 파일 선택 창에서 ⌘⇧. 으로 표시)

- 첫 실행 시 기본 폴더(`~/.claude`, `~/.codex`)의 로그인은 자동으로 등록된다.
- 메뉴바와 위젯에 표시할 계정은 카드 오른쪽 위 버튼이나 설정에서 고른다.
- 계정을 제거해도 CLI 로그인은 그대로 남는다.
- 평소 그 계정으로 CLI 를 쓸 때도 같은 환경 변수를 붙여 실행해야 한다 (`alias claude-work='CLAUDE_CONFIG_DIR=~/.claude-work claude'` 권장).

## 요구 사항

- macOS 26 이상, Xcode 26 이상
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## 빌드 & 실행

```sh
xcodegen generate          # project.yml → yoUsage.xcodeproj (Info.plist, entitlements 도 함께 생성)
open yoUsage.xcodeproj     # yoUsage 스킴 선택 후 ⌘R
```

CLI 로만 빌드하려면:

```sh
xcodebuild -project yoUsage.xcodeproj -scheme yoUsage -derivedDataPath build build
open build/Build/Products/Debug/yoUsage.app
```

실행하면 Dock 아이콘 없이 메뉴바에 게이지 아이콘과 잔여 쿼터(예: `85%`)가 나타난다.
메뉴바 항목이 많아 가려진다면 다른 항목을 ⌘-드래그로 정리한다.

위젯은 앱을 한 번 실행한 뒤 바탕화면 우클릭 → **위젯 편집** → "yoUsage" 에서 추가한다.

## 프로젝트 구조

```
project.yml                  XcodeGen 정의 (타깃, 서명, Info.plist, entitlements)
Shared/                      앱·위젯 양쪽 타깃에 포함
  Models/AccountUsage.swift    ProviderKind, Account, AccountUsage, UsageLimit, UsageSnapshot
  Models/UsageLevel.swift      여유/주의/임박 단계와 색상
  Storage/SharedStore.swift    App Group 컨테이너의 JSON 스냅샷 저장소
  Views/UsageViews.swift       ResetCountdownText, UsageRing
yoUsage/                     메뉴바 앱
  yoUsageApp.swift             MenuBarExtra(.window) + Settings
  UsageManager.swift           @Observable 상태, 자동 폴링, 위젯 스냅샷 발행
  Providers/                   UsageProvider 프로토콜, ClaudeCodeProvider, CodexProvider, MockUsageProvider(프리뷰용)
  Views/                       UsagePopoverView, AccountCardView, SettingsView
yoUsageWidget/               WidgetKit 확장 (systemSmall)
```

## 설정 가이드

모든 설정은 `project.yml` 에 있고 `xcodegen generate` 가 plist/entitlements 를 만들어 준다.

| 항목 | 값 | 위치 |
| --- | --- | --- |
| Deployment Target | macOS 26.0 | `options.deploymentTarget` |
| Swift 언어 모드 | 6 (strict concurrency) | `SWIFT_VERSION` |
| Dock 아이콘 숨김 | `LSUIElement = YES` | 앱 Info.plist |
| 위젯 확장 포인트 | `com.apple.widgetkit-extension` | 위젯 Info.plist |
| App Sandbox | 앱: 꺼짐 (키체인·`~/.claude`·`~/.codex` 읽기), 위젯: 켜짐 (필수) | entitlements |
| App Group | `$(TeamIdentifierPrefix)com.yousage.shared` | `APP_GROUP_ID` |

### 서명과 App Group

- 기본값은 Team 없이 ad-hoc 서명("Sign to Run Locally")이라 Apple 계정 없이도 빌드·실행된다.
- 배포하거나 위젯 데이터 공유가 동작하지 않으면 `project.yml` 의 `DEVELOPMENT_TEAM` 에 Team ID 를 넣고
  `xcodegen generate` 를 다시 실행한다. App Group ID 가 `<TeamID>.com.yousage.shared` 로 바뀌며,
  코드에서는 Info.plist 의 `AppGroupIdentifier` 로 읽으므로 수정할 곳은 없다.
- iOS 스타일 `group.` 접두사 ID 는 프로비저닝 프로파일이 필요하므로 쓰지 않는다.
- ad-hoc 빌드에서는 샌드박스 밖의 앱이 App Group 컨테이너에 쓸 수 없다. 이때 스냅샷은
  `~/Library/Application Support/yoUsage/usage-snapshot.json` 에 저장되고, 위젯은 이 폴더에 대한
  읽기 전용 샌드박스 예외로 읽는다 (`Shared/Storage/SharedStore.swift`).

### 샌드박스를 끈 이유

앱은 `/usr/bin/security` 로 키체인을 읽고 홈 폴더의 CLI 설정 파일을 읽어야 해서 샌드박스 밖에서 동작한다.
따라서 Mac App Store 배포는 불가하고, 직접 빌드하거나 공증(notarize)한 빌드로 배포한다.
위젯은 토큰을 다루지 않고 App Group 컨테이너의 스냅샷(JSON)만 읽는다.

## Provider 추가하기

1. `ProviderKind` 에 case 추가 (표시 이름, 아이콘, 기본 설정 폴더, 사용량 페이지 URL).
2. `UsageProvider` 구현 — 로그인 정보를 읽고 사용량 API 를 호출해 `AccountUsage` 로 변환.
3. `UsageManager.init` 의 `providers` 기본값에 추가.

```swift
struct GeminiProvider: UsageProvider {
    let kind = ProviderKind.gemini

    func fetchUsage(for account: Account) async throws -> AccountUsage {
        // account.configDirectory 에서 인증 정보 로드 → 사용량 조회 → AccountUsage 로 변환
    }
}
```

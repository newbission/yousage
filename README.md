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
| ① 토큰 위치 | macOS 키체인 `Claude Code-credentials` (`/usr/bin/security` 로 읽음) 와 `<설정 폴더>/.credentials.json` 중 만료가 더 늦은 쪽. SSH 세션에서 실행한 Claude Code 는 키체인 대신 파일을 갱신한다 | `<설정 폴더>/auth.json` |
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

## 터미널에서 보기

SSH 로 접속했거나 tmux · zellij 안에 있어서 메뉴바를 볼 수 없을 때는 `yousage` 명령을 쓴다.
API 를 직접 부르지 않고 메뉴바 앱이 갱신해 둔 스냅샷 파일만 읽으므로, 키체인이 잠긴 SSH 세션에서도 동작한다.
대신 그 Mac 에 로그인된 상태로 앱이 실행 중이어야 값이 갱신된다 (15분 넘게 갱신이 없으면 `⚠` 로 표시).

```sh
# 최적화 빌드 후 PATH 에 연결 (앱 빌드에도 디버그 버전이 함께 만들어진다)
xcodebuild -project yoUsage.xcodeproj -target yoUsageCLI -configuration Release SYMROOT="$PWD/build/release" build
ln -sf "$PWD/build/release/Release/yousage" ~/.local/bin/yousage

yousage            # 계정별 상세 (5시간 · 주간 · 모델별 주간, 리셋까지 남은 시간)
yousage --short    # 한 줄 요약: Claude Code 5h 12%(3h40m) 주 4% │ Codex 5h 0% 주 1%
yousage --json     # 스냅샷 원본
```

### 터미널 창 제목에 붙이기

`yousage title` 은 셸(또는 지정한 명령)을 감싸 실행하면서, 안쪽 프로그램이 정한 창 제목 **끝에** 사용량을 붙인다.

```
yousage-test | claude 작업  —  Claude Code 5h 1%(4h32m) 주 3% │ Codex 5h 23%(4h35m) 주 12%
```

- 출력은 그대로 통과시키고 창 제목을 바꾸는 이스케이프(OSC 0/2)만 고쳐 쓴다. 셸 · zellij · Claude Code 가 정한 제목은 그대로 살아 있다.
- 바깥 터미널에 쓰는 프로세스가 하나뿐이라 다른 출력 사이에 끼어들어 화면이 깨지지 않는다. 사용량은 30초마다 다시 읽는다.
- 종료하면 사용량이 빠진 원래 제목으로 되돌린다. 이미 감싼 세션 안에서 다시 실행하면 아무것도 하지 않는다.

SSH 로 접속할 때마다 자동으로 켜려면 `~/.zshrc` **맨 끝**에:

```zsh
if [[ -n $SSH_CONNECTION && -z $YOUSAGE_TITLE ]] && (( $+commands[yousage] )); then
  yousage title && exit   # 래퍼가 비정상 종료하면 exit 하지 않으므로 평소 셸이 남는다
fi
```

화면과 터미널의 퍼센트 및 게이지는 **남은 양**이다 (100% → 0%). 남은 양이 적어지면 주황색·빨간색으로 경고한다. `--json`의 `usedPercent`는 원본 사용률을 유지한다. `--short` 는 터미널이 아닌 곳으로 출력할 때 색을 빼므로, 색이 필요하면 `--color` 를 붙인다.

**Claude Code 상태줄** — `/usage` 를 치지 않아도 입력창 아래에 항상 보인다. `~/.claude/settings.json`:

```json
{ "statusLine": { "type": "command", "command": "yousage --short --color" } }
```

**tmux** — `~/.tmux.conf`:

```
set -g status-interval 60
set -g status-right "#(yousage --short)"
```

**zellij** — 기본 상태바는 명령 출력을 못 넣으므로 [zjstatus](https://github.com/dj95/zjstatus) 플러그인을 쓴다. 레이아웃의 zjstatus 설정에:

```kdl
format_right          "{command_usage}"
command_usage_command  "yousage --short"
command_usage_format   "{stdout}"
command_usage_interval "60"
```

## 프로젝트 구조

```
project.yml                  XcodeGen 정의 (타깃, 서명, Info.plist, entitlements)
Shared/                      앱·위젯·명령 타깃에 포함
  Models/AccountUsage.swift    ProviderKind, Account, AccountUsage, UsageLimit, UsageSnapshot
  Models/UsageLevel.swift      여유/주의/임박 단계와 색상
  Storage/SharedStore.swift    JSON 스냅샷 저장소 (App Group 컨테이너 + Application Support)
  Views/UsageViews.swift       ResetCountdownText, UsageRing
yoUsage/                     메뉴바 앱
  yoUsageApp.swift             MenuBarExtra(.window) + Settings
  UsageManager.swift           @Observable 상태, 자동 폴링, 위젯 스냅샷 발행
  Providers/                   UsageProvider 프로토콜, ClaudeCodeProvider, CodexProvider, MockUsageProvider(프리뷰용)
  Views/                       UsagePopoverView, AccountCardView, SettingsView
yoUsageWidget/               WidgetKit 확장 (systemSmall)
yoUsageCLI/                  `yousage` 터미널 명령 (스냅샷을 읽어 출력)
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
- 스냅샷은 App Group 컨테이너와 `~/Library/Application Support/yoUsage/usage-snapshot.json` 두 곳에 저장된다.
  ad-hoc 빌드에서는 샌드박스 밖의 앱이 App Group 컨테이너에 쓸 수 없고, `yousage` 명령은 그 컨테이너를
  읽을 수 없기 때문이다. 위젯은 뒤쪽 폴더를 읽기 전용 샌드박스 예외로 읽는다 (`Shared/Storage/SharedStore.swift`).

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

### 표시 방식과 색상 기준

설정 → 용량 표시 · 색상 기준에서 남은 용량/사용한 양을 고르고 주의·위험 기준을 1% 단위로 조정한다.
기본값은 남은 용량, 주의는 사용률 60% 이상(잔여 40% 이하), 위험은 사용률 85% 이상(잔여 15% 이하)이다.
색상 기준은 항상 사용률 기준이며 표시 방향을 바꿔도 경고의 의미는 같다.
설정은 저장되며 메뉴바·팝업·위젯·터미널에 적용된다. 기본값 복원도 지원한다.

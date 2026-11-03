# README 미디어 생성

저장소 루트에서 `tools/readme/generate.sh`를 실행합니다. Xcode 26 이상이 필요합니다.

- 앱의 `UsagePopoverView`, `AccountCardView`, `MenuBarGauge`와 실제 위젯 뷰를 재사용합니다.
- AppKit 호스팅 뷰를 비트맵으로 렌더링하고 ImageIO로 PNG와 반복 GIF를 저장합니다.
- 터미널 이미지는 예시 스냅샷을 실제 CLI의 `shortSummary`로 포맷한 출력입니다. 터미널 앱 캡처는 아닙니다.
- 인증 정보 및 실제 계정 데이터를 읽지 않습니다. 전용 UserDefaults와 예시 Provider를 사용하며 API 요청 및 공유 스냅샷 저장을 하지 않습니다.
- GIF는 기본 경고 기준에 따라 잔량 82% → 10% 변화를 압축해 보여주는 설명 자료입니다. 사용 화면 녹화가 아닙니다.
- 위젯은 macOS 위젯 호스트를 제외한 실제 콘텐츠 뷰를 렌더링합니다.

생성물은 `docs/assets/`의 `accounts.png`, `widget.png`, `terminal.png`, `quota-poster.png`, `quota-states.gif`입니다. 임시 컴파일 결과물은 자동 삭제합니다.

# README 미디어 생성

저장소 루트에서 `tools/readme/generate.sh`를 실행합니다. Xcode 26 이상이 필요합니다.

- 앱의 `UsagePopoverView`, `AccountCardView`, `MenuBarGauge`와 실제 위젯 뷰를 재사용합니다.
- AppKit 호스팅 뷰를 비트맵으로 렌더링하고 ImageIO로 PNG와 반복 GIF를 저장합니다.
- 터미널 이미지는 예시 스냅샷을 실제 CLI의 `shortSummary`로 포맷한 출력입니다. 터미널 앱 캡처는 아닙니다.
- 인증 정보 및 실제 계정 데이터를 읽지 않습니다. 전용 UserDefaults와 예시 Provider를 사용하며 API 요청 및 공유 스냅샷 저장을 하지 않습니다.
- GIF는 기본 경고 기준에 따라 잔량 82% → 10% 변화를 압축해 보여주는 설명 자료입니다. 사용 화면 녹화가 아닙니다.
- 위젯은 macOS 위젯 호스트를 제외한 실제 콘텐츠 뷰를 렌더링합니다.

생성물은 `docs/assets/`의 `accounts.png`, `widget.png`, `terminal.png`, `quota-poster.png`, `quota-states.gif`입니다. 임시 컴파일 결과물은 자동 삭제합니다.

설정 화면도 실제 `SettingsView`를 사용합니다. 전체 항목을 보여 주기 위해 임시 복사본의 높이만 740 → 1240으로 늘립니다. 제품 소스는 수정하지 않습니다. `settings-display.png`와 `settings-accounts.png`는 동일 렌더링에서 잘라낸 영역입니다. `tools/readme/generate.sh --settings-only`로 설정 이미지만 갱신할 수 있습니다. 계정·메일은 예시이며 자동 시작을 등록하거나 실제 계정을 추가하지 않습니다.

`docs/assets/account-setup.svg`는 등록 순서를 정리한 안내도입니다. 메뉴·폴더 선택 창의 캡처가 아닙니다.

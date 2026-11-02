import Foundation

// 메뉴바를 볼 수 없는 환경(SSH, tmux, zellij, Claude Code 상태줄)에서 사용량을 확인하는 명령.
// 직접 API 를 부르지 않고, 메뉴바 앱이 갱신해 둔 스냅샷 파일만 읽는다.

if CommandLine.arguments.dropFirst().first == "title" {
    TitleWrapper.run(Array(CommandLine.arguments.dropFirst(2).drop { $0 == "--" }))
}

let usage = """
사용법: yousage [옵션]

  (옵션 없음)   계정별 상세 표시
  -s, --short   한 줄 요약 (tmux · zellij · Claude Code 상태줄용)
  -j, --json    스냅샷 원본 JSON
      --color   터미널이 아니어도 색상 사용
      --no-color
  -h, --help

  yousage title [명령 …]
                명령(기본: 로그인 셸)을 실행하면서 터미널 창 제목 끝에 사용량을 붙인다.
                예) SSH 접속 시 .zshrc 끝에서 yousage title && exit (README 참고)
"""

var arguments = Set(CommandLine.arguments.dropFirst())
if arguments.contains("-h") || arguments.contains("--help") {
    print(usage)
    exit(0)
}
let short = arguments.remove("-s") != nil || arguments.remove("--short") != nil
let json = arguments.remove("-j") != nil || arguments.remove("--json") != nil
let forceColor = arguments.remove("--color") != nil
let noColor = arguments.remove("--no-color") != nil
if let unknown = arguments.first {
    FileHandle.standardError.write(Data("알 수 없는 옵션: \(unknown)\n\n\(usage)\n".utf8))
    exit(2)
}
let useColor = !noColor && (forceColor || isatty(STDOUT_FILENO) == 1)

guard let snapshot = SharedStore.loadFallback() else {
    if short {
        print("yoUsage: 데이터 없음")
    } else {
        FileHandle.standardError.write(Data("스냅샷이 없습니다. 이 Mac 에서 yoUsage 앱을 한 번 실행해 주세요.\n".utf8))
    }
    exit(1)
}

if json {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    print(String(decoding: try encoder.encode(snapshot), as: UTF8.self))
    exit(0)
}

let now = Date.now
let style = Style(color: useColor, preferences: snapshot.displayPreferences ?? .init())

if short {
    print(shortSummary(snapshot, at: now, style: style))
    exit(0)
}

for usage in snapshot.usages {
    let subtitle = [usage.provider.displayName, usage.plan, usage.email].compactMap { $0 }.filter { $0 != usage.name }.joined(separator: " · ")
    print("\(usage.name)  \(style.dim(subtitle))")
    let all = rows(for: usage)
    let titleWidth = all.map { displayWidth($0.title) }.max() ?? 0
    for row in all {
        let percent = row.effectivePercent(at: now)
        let remaining = style.preferences.percent(used: percent)
        let filled = Int((remaining / 10).rounded(.up))
        let bar = String(repeating: "█", count: filled) + String(repeating: "░", count: 10 - filled)
        let number = String(repeating: " ", count: max(0, 3 - "\(Int(remaining.rounded()))".count)) + "\(Int(remaining.rounded()))%"
        let reset = row.countdown(at: now).map { "\($0) 후 리셋" } ?? ""
        print("  \(padded(row.title, to: titleWidth))  \(style.level(bar, percent: percent)) \(number) \(style.preferences.label)  \(style.dim(reset))")
    }
    print()
}
let updated = snapshot.updatedAt.formatted(date: .omitted, time: .shortened)
if let staleMinutes = staleMinutes(of: snapshot, at: now) {
    print("⚠ \(staleMinutes)분 전(\(updated)) 데이터입니다. yoUsage 앱이 실행 중인지 확인하세요.")
} else {
    print(style.dim("\(updated) 업데이트"))
}

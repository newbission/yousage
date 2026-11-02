import Darwin
import Foundation

/// `yousage title [명령 …]`
///
/// 명령(기본은 로그인 셸)을 가상 터미널 안에서 실행하고, 출력은 그대로 바깥 터미널로 흘려보낸다.
/// 그 사이에서 창 제목을 바꾸는 이스케이프(OSC 0/2)만 골라 "원래 제목 — 사용량" 으로 고쳐 쓴다.
/// 안쪽 프로그램(셸, zellij, Claude Code 등)이 정한 제목은 그대로 살아 있고 끝에 사용량만 붙는다.
/// 바깥 터미널에 쓰는 것은 이 프로세스 하나뿐이라, 다른 출력 중간에 끼어들어 화면이 깨지지 않는다.
enum TitleWrapper {
    private static let refreshInterval: TimeInterval = 30

    static func run(_ arguments: [String]) -> Never {
        let command = arguments.isEmpty
            ? [ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh", "-l"]
            : arguments

        // 이미 감싼 세션 안이거나 터미널이 아니면 중계할 필요 없이 바로 실행한다.
        guard getenv(environmentKey) == nil, isatty(STDIN_FILENO) == 1, isatty(STDOUT_FILENO) == 1 else {
            execute(command)
        }
        setenv(environmentKey, "1", 1)

        var originalMode = termios()
        tcgetattr(STDIN_FILENO, &originalMode)
        var size = winsize()
        _ = ioctl(STDIN_FILENO, TIOCGWINSZ, &size)

        let argv = command.map { strdup($0) } + [nil]
        var master: Int32 = -1
        let pid = forkpty(&master, nil, &originalMode, &size)
        if pid < 0 { execute(command) }
        if pid == 0 {
            execvp(argv[0]!, argv)
            perror(command[0])
            _exit(127)
        }

        var rawMode = originalMode
        cfmakeraw(&rawMode)
        tcsetattr(STDIN_FILENO, TCSANOW, &rawMode)
        signal(SIGWINCH) { _ in windowSizeChanged = true }

        var filter = TitleFilter()
        var lastRefresh = Date.distantPast
        var titlePending = false
        var fds = [
            pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0),
            pollfd(fd: master, events: Int16(POLLIN), revents: 0),
        ]
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)

        loop: while true {
            if windowSizeChanged {
                windowSizeChanged = false
                if ioctl(STDIN_FILENO, TIOCGWINSZ, &size) == 0 { _ = ioctl(master, TIOCSWINSZ, &size) }
            }

            if Date.now.timeIntervalSince(lastRefresh) >= refreshInterval {
                lastRefresh = .now
                let suffix = SharedStore.loadFallback().map { shortSummary($0, at: .now, style: Style(color: false)) }
                if suffix != filter.suffix {
                    filter.suffix = suffix
                    titlePending = true
                }
            }
            // 이스케이프 시퀀스나 한글 바이트 중간에는 끼워 넣지 않는다.
            if titlePending, filter.isAtBoundary {
                titlePending = false
                writeAll(STDOUT_FILENO, filter.titleSequence())
            }

            let ready = poll(&fds, 2, 1000)
            if ready < 0 {
                if errno == EINTR { continue }
                break
            }
            if fds[0].revents & Int16(POLLIN | POLLHUP) != 0 {
                let count = read(STDIN_FILENO, &buffer, buffer.count)
                if count > 0 {
                    writeAll(master, buffer[0..<count])
                } else {
                    fds[0].fd = -1 // 입력이 닫혀도 출력은 끝까지 흘려보낸다.
                }
            }
            if fds[1].revents & Int16(POLLIN | POLLHUP | POLLERR) != 0 {
                let count = read(master, &buffer, buffer.count)
                guard count > 0 else { break loop } // 안쪽 프로그램이 끝남
                writeAll(STDOUT_FILENO, filter.process(buffer[0..<count]))
            }
        }

        tcsetattr(STDIN_FILENO, TCSANOW, &originalMode)
        // 사용량이 붙은 제목이 남지 않도록 마지막 원래 제목으로 되돌린다.
        if let title = filter.originalTitle {
            writeAll(STDOUT_FILENO, Array("\u{1B}]2;\(title)\u{07}".utf8))
        }
        var status: Int32 = 0
        waitpid(pid, &status, 0)
        exit((status & 0x7F) == 0 ? (status >> 8) & 0xFF : 128 + (status & 0x7F))
    }

    static let environmentKey = "YOUSAGE_TITLE"

    private static func execute(_ command: [String]) -> Never {
        let argv = command.map { strdup($0) } + [nil]
        execvp(argv[0]!, argv)
        perror(command[0])
        exit(127)
    }

    private static func writeAll(_ fd: Int32, _ bytes: some Collection<UInt8>) {
        var bytes = Array(bytes)[...]
        while !bytes.isEmpty {
            let written = bytes.withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
            if written < 0 {
                if errno == EINTR || errno == EAGAIN { continue }
                return
            }
            bytes = bytes.dropFirst(written)
        }
    }
}

nonisolated(unsafe) private var windowSizeChanged = false

/// 출력 바이트를 그대로 통과시키면서 창 제목 이스케이프만 고쳐 쓰는 상태 기계.
struct TitleFilter {
    private enum State {
        case ground
        case escape           // ESC
        case escapeIntermediate // ESC ( 등, 마지막 바이트 대기
        case csi              // ESC [
        case osc              // ESC ] … BEL 또는 ESC \
        case oscEscape
        case string           // DCS · APC · PM · SOS … ESC \
        case stringEscape
    }

    private static let maxOSCLength = 4096

    private var state = State.ground
    private var oscBytes: [UInt8] = []
    private var pendingUTF8 = 0

    /// 안쪽 프로그램이 마지막으로 정한 제목.
    private(set) var originalTitle: String?
    /// 제목 끝에 붙일 사용량. `nil` 이면 제목을 고치지 않는다.
    var suffix: String?

    var isAtBoundary: Bool { state == .ground && pendingUTF8 == 0 }

    func titleSequence(code: UInt8 = UInt8(ascii: "2"), terminator: [UInt8] = [0x07]) -> [UInt8] {
        let title = switch (originalTitle, suffix) {
        case (let original?, let suffix?) where !original.isEmpty: "\(original)  —  \(suffix)"
        case (_, let suffix?): suffix
        case (let original, nil): original ?? ""
        }
        let safe = title.unicodeScalars.filter { $0.value >= 0x20 && $0.value != 0x7F }
        return [0x1B, 0x5D, code, UInt8(ascii: ";")] + Array(String(String.UnicodeScalarView(safe)).utf8) + terminator
    }

    mutating func process(_ input: ArraySlice<UInt8>) -> [UInt8] {
        var output: [UInt8] = []
        output.reserveCapacity(input.count + 64)
        var index = input.startIndex
        while index < input.endIndex {
            guard state == .ground else {
                feed(input[index], into: &output)
                index += 1
                continue
            }
            // 일반 텍스트는 다음 ESC 까지 통째로 복사한다.
            let end = input[index...].firstIndex(of: 0x1B) ?? input.endIndex
            if end > index {
                output.append(contentsOf: input[index..<end])
                trackUTF8(input[index..<end])
            }
            index = end
            if index < input.endIndex {
                feed(input[index], into: &output)
                index += 1
            }
        }
        return output
    }

    /// 텍스트 끝이 여러 바이트 문자의 중간에서 끊겼는지 기록한다.
    private mutating func trackUTF8(_ run: ArraySlice<UInt8>) {
        var continuation = 0
        for byte in run.reversed().prefix(4) {
            guard byte & 0xC0 == 0x80 else {
                let length = switch byte {
                case 0xF0...: 4
                case 0xE0...: 3
                case 0xC0...: 2
                default: 1
                }
                pendingUTF8 = max(0, length - 1 - continuation)
                return
            }
            continuation += 1
        }
        pendingUTF8 = max(0, pendingUTF8 - continuation)
    }

    private mutating func feed(_ byte: UInt8, into output: inout [UInt8]) {
        switch state {
        case .ground:
            if byte == 0x1B {
                state = .escape // ESC 는 다음 바이트를 보고 나서 내보낸다.
                pendingUTF8 = 0
                return
            }
            output.append(byte)
            trackUTF8([byte][...])

        case .escape:
            switch byte {
            case UInt8(ascii: "]"):
                state = .osc
                oscBytes.removeAll(keepingCapacity: true)
            case 0x1B:
                output.append(0x1B)
            default:
                output += [0x1B, byte]
                state = switch byte {
                case UInt8(ascii: "["): .csi
                case UInt8(ascii: "P"), UInt8(ascii: "_"), UInt8(ascii: "^"), UInt8(ascii: "X"): .string
                case 0x20...0x2F: .escapeIntermediate
                default: .ground
                }
            }

        case .escapeIntermediate:
            output.append(byte)
            if byte >= 0x30 { state = .ground }

        case .csi:
            output.append(byte)
            if (0x40...0x7E).contains(byte) { state = .ground }

        case .osc:
            switch byte {
            case 0x07:
                finishOSC(terminator: [0x07], into: &output)
            case 0x1B:
                state = .oscEscape
            default:
                oscBytes.append(byte)
                if oscBytes.count > Self.maxOSCLength {
                    // 제목이 아닌 긴 OSC(이미지 등)는 해석하지 않고 흘려보낸다.
                    output += [0x1B, 0x5D] + oscBytes
                    oscBytes.removeAll()
                    state = .string
                }
            }

        case .oscEscape:
            if byte == UInt8(ascii: "\\") {
                finishOSC(terminator: [0x1B, byte], into: &output)
            } else {
                output += [0x1B, 0x5D] + oscBytes
                state = .escape
                feed(byte, into: &output)
            }

        case .string:
            output.append(byte)
            if byte == 0x1B { state = .stringEscape } else if byte == 0x07 { state = .ground }

        case .stringEscape:
            output.append(byte)
            state = byte == UInt8(ascii: "\\") ? .ground : .string
        }
    }

    private mutating func finishOSC(terminator: [UInt8], into output: inout [UInt8]) {
        state = .ground
        // OSC 0 은 아이콘 이름과 제목, OSC 2 는 제목만 바꾼다.
        if oscBytes.count >= 2, oscBytes[1] == UInt8(ascii: ";"),
           oscBytes[0] == UInt8(ascii: "0") || oscBytes[0] == UInt8(ascii: "2") {
            originalTitle = String(decoding: oscBytes.dropFirst(2), as: UTF8.self)
            output += titleSequence(code: oscBytes[0], terminator: terminator)
        } else {
            output += [0x1B, 0x5D] + oscBytes + terminator
        }
    }
}

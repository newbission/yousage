import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Environment(UsageManager.self) private var manager
    @Environment(\.scenePhase) private var scenePhase
    @State private var loginItemStatus = SMAppService.mainApp.status
    @State private var loginItemError: String?

    var body: some View {
        @Bindable var manager = manager

        Form {
            Section("일반") {
                Toggle("로그인 시 자동 시작", isOn: Binding(
                    get: { loginItemStatus == .enabled || loginItemStatus == .requiresApproval },
                    set: { setLaunchAtLogin($0) }
                ))

                if loginItemStatus == .requiresApproval {
                    Text("자동 시작을 허용하려면 시스템 설정의 로그인 항목에서 yoUsage를 켜 주세요.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("로그인 항목 설정 열기") {
                        SMAppService.openSystemSettingsLoginItems()
                    }
                }

                if let loginItemError {
                    Text(loginItemError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }

            Section {
                if manager.accounts.isEmpty {
                    Text("연결된 계정이 없습니다.")
                        .foregroundStyle(.secondary)
                }
                ForEach(manager.accounts) { account in
                    accountRow(account)
                }
                addMenu
            } header: {
                Text("연결된 계정")
            } footer: {
                // `~` 가 마크다운 취소선으로 해석되지 않도록 verbatim 으로 표시한다.
                Text(verbatim: "계정 하나는 CLI 설정 폴더 하나에 대응합니다. 두 번째 계정은 다른 폴더로 로그인한 뒤 그 폴더를 추가하세요.\n예) CLAUDE_CONFIG_DIR=~/.claude-work claude\n예) CODEX_HOME=~/.codex-work codex login")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Section("메뉴바 · 위젯") {
                Picker("표시할 계정", selection: $manager.activeAccountID) {
                    ForEach(manager.accounts) { account in
                        Text("\(account.name) (\(account.provider.displayName))")
                            .tag(Optional(account.id))
                    }
                }
            }

            Section {
                Picker("퍼센트 표시", selection: $manager.displayPreferences.showsRemaining) {
                    Text("남은 용량").tag(true)
                    Text("사용한 양").tag(false)
                }
                Stepper("주의 (주황): 사용률 \(manager.displayPreferences.cautionPercent)% 이상",
                        value: $manager.displayPreferences.cautionPercent,
                        in: 1...(manager.displayPreferences.criticalPercent - 1))
                Stepper("위험 (빨강): 사용률 \(manager.displayPreferences.criticalPercent)% 이상",
                        value: $manager.displayPreferences.criticalPercent,
                        in: (manager.displayPreferences.cautionPercent + 1)...100)
                HStack {
                    ForEach([UsageLevel.comfortable, .caution, .critical], id: \.label) { level in
                        Label(level.label, systemImage: "circle.fill")
                            .foregroundStyle(level.color)
                    }
                }
                .font(.caption)
                Button("표시 설정 기본값으로 복원") {
                    manager.displayPreferences = .init()
                }
            } header: {
                Text("용량 표시 · 색상 기준")
            } footer: {
                Text("색상 기준은 사용한 양 기준입니다. 남은 용량으로 볼 때 주의는 \(100 - manager.displayPreferences.cautionPercent)% 이하, 위험은 \(100 - manager.displayPreferences.criticalPercent)% 이하입니다. 메뉴바·팝업·위젯·터미널에 함께 적용됩니다.")
                    .font(.caption)
            }

            Section("새로고침") {
                Picker("자동 폴링 주기", selection: $manager.pollingInterval) {
                    Text("1분").tag(TimeInterval(60))
                    Text("3분").tag(TimeInterval(180))
                    Text("5분").tag(TimeInterval(300))
                    Text("10분").tag(TimeInterval(600))
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .frame(height: 680)
        .onAppear { loginItemStatus = SMAppService.mainApp.status }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                loginItemStatus = SMAppService.mainApp.status
            }
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        loginItemError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            loginItemError = "자동 시작 설정을 변경하지 못했습니다: \(error.localizedDescription)"
        }
        loginItemStatus = SMAppService.mainApp.status
    }

    private func accountRow(_ account: Account) -> some View {
        HStack(spacing: 10) {
            Image(systemName: account.provider.symbolName)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                TextField("이름", text: Binding(
                    get: { account.name },
                    set: { manager.renameAccount(account.id, to: $0) }
                ))
                .labelsHidden()
                .textFieldStyle(.plain)
                .multilineTextAlignment(.leading)
                .font(.body.weight(.medium))

                Text(subtitle(for: account))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let error = manager.errors[account.id] {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            Image(systemName: "circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(statusColor(for: account))
                .help(statusLabel(for: account))

            Button(role: .destructive) {
                manager.removeAccount(account.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("계정 제거 (CLI 로그인은 그대로 유지됩니다)")
        }
    }

    /// "Claude Code · user@example.com · ~/.claude"
    private func subtitle(for account: Account) -> String {
        let path = NSString(string: account.configDirectory.path).abbreviatingWithTildeInPath
        return [account.provider.displayName, manager.usage(for: account)?.email, path]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private func statusColor(for account: Account) -> Color {
        if manager.errors[account.id] != nil { return .red }
        return manager.usage(for: account) == nil ? .gray : .green
    }

    private func statusLabel(for account: Account) -> String {
        if manager.errors[account.id] != nil { return "조회 실패" }
        return manager.usage(for: account) == nil ? "확인 중" : "연결됨"
    }

    private var addMenu: some View {
        Menu("계정 추가", systemImage: "plus") {
            ForEach(ProviderKind.allCases, id: \.self) { kind in
                Section(kind.displayName) {
                    Button("기본 폴더 (\(kind.defaultConfigPath))") {
                        manager.addAccount(name: kind.displayName, provider: kind, configPath: nil)
                    }
                    .disabled(manager.hasAccount(provider: kind, configPath: nil))

                    Button("다른 설정 폴더 선택…") {
                        chooseFolder(for: kind)
                    }
                }
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func chooseFolder(for kind: ProviderKind) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.showsHiddenFiles = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        panel.message = "\(kind.displayName) 에 로그인할 때 사용한 설정 폴더를 선택하세요."
        panel.prompt = "추가"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        manager.addAccount(name: url.lastPathComponent, provider: kind, configPath: url.path)
    }
}

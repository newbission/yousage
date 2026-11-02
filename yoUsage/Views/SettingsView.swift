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
            Section {
                HStack(spacing: 14) {
                    BrandBadge(size: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("yoUsage")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        Text("구독의 여유를, 한눈에.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
                Text("Claude Code · Codex 구독 계정의 한도와 리셋 시간을 확인합니다. API 키로 사용하는 종량제 비용은 추적하지 않습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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
                Picker("퍼센트 표시", selection: $manager.displayPreferences.showsRemaining) {
                    Text("남은 용량").tag(true)
                    Text("사용한 양").tag(false)
                }
                .pickerStyle(.segmented)
                displayPreview
                Stepper("주의 (노랑): 사용률 \(manager.displayPreferences.cautionPercent)% 이상",
                        value: $manager.displayPreferences.cautionPercent,
                        in: 1...(manager.displayPreferences.criticalPercent - 1))
                Stepper("위험 (빨강): 사용률 \(manager.displayPreferences.criticalPercent)% 이상",
                        value: $manager.displayPreferences.criticalPercent,
                        in: (manager.displayPreferences.cautionPercent + 1)...100)
                Button("표시 설정 기본값으로 복원") {
                    manager.displayPreferences = .init()
                }
            } header: {
                Text("용량 표시 · 색상 기준")
            } footer: {
                Text("색상 기준은 사용한 양 기준입니다. 남은 용량으로 볼 때 주의는 \(100 - manager.displayPreferences.cautionPercent)% 이하, 위험은 \(100 - manager.displayPreferences.criticalPercent)% 이하입니다. 메뉴바·팝업·위젯·터미널에 함께 적용됩니다.")
                    .font(.caption)
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
                Text("연결된 구독 계정")
            } footer: {
                // `~` 가 마크다운 취소선으로 해석되지 않도록 verbatim 으로 표시한다.
                Text(verbatim: "CLI에 로그인된 구독 계정을 연결합니다. 다른 계정은 별도로 로그인한 설정 폴더를 선택하세요.")
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
        .tint(YoUsageStyle.accent)
        .frame(width: 520)
        .frame(height: 740)
        .onAppear { loginItemStatus = SMAppService.mainApp.status }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                loginItemStatus = SMAppService.mainApp.status
            }
        }
    }

    private var displayPreview: some View {
        let preferences = manager.displayPreferences
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("표시 미리보기")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("사용률 50% 예시")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            HStack(spacing: 16) {
                UsageRing(usedPercent: 50, lineWidth: 5)
                    .frame(width: 42, height: 42)
                Text("\(Int(preferences.percent(used: 50)))% \(preferences.label)")
                    .font(.system(size: 23, weight: .semibold, design: .rounded))
                Spacer()
                Text(UsageLevel(usedPercent: 50, preferences: preferences).label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(UsageLevel(usedPercent: 50, preferences: preferences).color)
            }
            GeometryReader { proxy in
                HStack(spacing: 2) {
                    Rectangle().fill(UsageLevel.comfortable.color)
                        .frame(width: proxy.size.width * Double(preferences.cautionPercent) / 100)
                    Rectangle().fill(UsageLevel.caution.color)
                        .frame(width: max(0, proxy.size.width * Double(preferences.criticalPercent - preferences.cautionPercent) / 100 - 2))
                    Rectangle().fill(UsageLevel.critical.color)
                }
                .clipShape(.capsule)
            }
            .frame(height: 5)
            HStack {
                Text("사용 0%")
                Spacer()
                Text("주의 \(preferences.cautionPercent)% · 위험 \(preferences.criticalPercent)%")
                Spacer()
                Text("100%")
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
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

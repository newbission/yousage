import Foundation
import Observation
import WidgetKit

@MainActor
@Observable
final class UsageManager {
    private(set) var accounts: [Account]
    private(set) var usages: [AccountUsage] = []
    /// 마지막 조회가 실패한 계정의 오류 메시지.
    private(set) var errors: [Account.ID: String] = [:]
    private(set) var isRefreshing = false
    private(set) var lastUpdated: Date?

    /// 메뉴바와 위젯에 표시할 계정.
    var activeAccountID: Account.ID? {
        didSet {
            defaults.set(activeAccountID?.uuidString, forKey: Keys.activeAccountID)
            publishSnapshot()
        }
    }

    /// 자동 폴링 주기(초).
    var pollingInterval: TimeInterval {
        didSet {
            defaults.set(pollingInterval, forKey: Keys.pollingInterval)
            startPolling()
        }
    }

    @ObservationIgnored private let providers: [ProviderKind: any UsageProvider]
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let sharesWithWidget: Bool
    @ObservationIgnored private var pollingTask: Task<Void, Never>?
    @ObservationIgnored private var needsAnotherRefresh = false

    private enum Keys {
        static let accounts = "accounts"
        static let activeAccountID = "activeAccountID"
        static let pollingInterval = "pollingInterval"
    }

    /// - Parameter providers: 서비스별 조회 구현체.
    init(
        providers: [any UsageProvider] = [ClaudeCodeProvider(), CodexProvider()],
        defaults: UserDefaults = .standard,
        sharesWithWidget: Bool = true
    ) {
        self.providers = Dictionary(providers.map { ($0.kind, $0) }, uniquingKeysWith: { _, new in new })
        self.defaults = defaults
        self.sharesWithWidget = sharesWithWidget

        let stored = defaults.data(forKey: Keys.accounts).flatMap { try? JSONDecoder().decode([Account].self, from: $0) }
        let accounts = stored ?? Self.detectAccounts()
        self.accounts = accounts

        let storedInterval = defaults.double(forKey: Keys.pollingInterval)
        pollingInterval = storedInterval > 0 ? storedInterval : 180
        activeAccountID = defaults.string(forKey: Keys.activeAccountID).flatMap(UUID.init)
            ?? accounts.first?.id

        if stored == nil { saveAccounts() }
        startPolling()
    }

    var activeUsage: AccountUsage? {
        usages.first { $0.id == activeAccountID } ?? usages.first
    }

    func usage(for account: Account) -> AccountUsage? {
        usages.first { $0.id == account.id }
    }

    // MARK: - Accounts

    /// 첫 실행 시 이 Mac 에 로그인되어 있는 CLI 를 찾아 기본 계정으로 등록한다.
    private static func detectAccounts() -> [Account] {
        ProviderKind.allCases
            .map { Account(id: UUID(), name: $0.displayName, provider: $0) }
            .filter { account in
                let directory = account.configDirectory
                let marker = switch account.provider {
                case .claudeCode: directory
                case .codex: directory.appending(path: "auth.json")
                }
                return FileManager.default.fileExists(atPath: marker.path)
            }
    }

    /// 같은 서비스·같은 설정 폴더의 계정이 이미 있는지.
    func hasAccount(provider: ProviderKind, configPath: String?) -> Bool {
        let candidate = Account(id: UUID(), name: "", provider: provider, configPath: configPath)
        return accounts.contains { $0.provider == provider && $0.configDirectory == candidate.configDirectory }
    }

    func addAccount(name: String, provider: ProviderKind, configPath: String?) {
        guard !hasAccount(provider: provider, configPath: configPath) else { return }
        let account = Account(id: UUID(), name: name, provider: provider, configPath: configPath)
        accounts.append(account)
        if activeAccountID == nil { activeAccountID = account.id }
        saveAccounts()
        Task { await refresh() }
    }

    func removeAccount(_ id: Account.ID) {
        accounts.removeAll { $0.id == id }
        usages.removeAll { $0.id == id }
        errors[id] = nil
        saveAccounts()
        if activeAccountID == id {
            activeAccountID = accounts.first?.id
        } else {
            publishSnapshot()
        }
    }

    func renameAccount(_ id: Account.ID, to name: String) {
        guard let index = accounts.firstIndex(where: { $0.id == id }) else { return }
        accounts[index].name = name
        if let usageIndex = usages.firstIndex(where: { $0.id == id }) {
            usages[usageIndex].name = name
        }
        saveAccounts()
        publishSnapshot()
    }

    private func saveAccounts() {
        defaults.set(try? JSONEncoder().encode(accounts), forKey: Keys.accounts)
    }

    // MARK: - Refresh

    func refresh() async {
        // 조회 중에 계정이 바뀌면 끝난 뒤 한 번 더 조회한다.
        guard !isRefreshing else {
            needsAnotherRefresh = true
            return
        }
        isRefreshing = true
        repeat {
            needsAnotherRefresh = false
            await fetchAll()
        } while needsAnotherRefresh
        isRefreshing = false
    }

    private func fetchAll() async {
        let providers = providers
        let requested = accounts
        let results = await withTaskGroup(of: (Account.ID, Result<AccountUsage, any Error>).self) { group in
            for account in requested {
                group.addTask {
                    guard let provider = providers[account.provider] else {
                        return (account.id, .failure(UsageError.unsupportedProvider(account.provider)))
                    }
                    do {
                        return (account.id, .success(try await provider.fetchUsage(for: account)))
                    } catch {
                        return (account.id, .failure(error))
                    }
                }
            }
            var collected: [Account.ID: Result<AccountUsage, any Error>] = [:]
            for await (id, result) in group {
                collected[id] = result
            }
            return collected
        }

        // 실패한 계정은 직전 값을 유지하고 오류만 기록한다.
        var updated: [AccountUsage] = []
        var failures: [Account.ID: String] = [:]
        for account in accounts {
            switch results[account.id] {
            case .success(var usage):
                usage.name = account.name
                updated.append(usage)
            case .failure(let error):
                failures[account.id] = error.localizedDescription
                if let previous = usage(for: account) { updated.append(previous) }
            case nil:
                if let previous = usage(for: account) { updated.append(previous) }
            }
        }
        usages = updated
        errors = failures
        lastUpdated = .now
        publishSnapshot()
    }

    // MARK: - Polling

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let delay = await self?.refreshAndNextDelay() else { return }
                try? await Task.sleep(for: .seconds(delay))
            }
        }
    }

    /// 폴링 주기와 가장 가까운 리셋 시각 중 빠른 쪽에 맞춰 다음 조회를 예약한다.
    private func refreshAndNextDelay() async -> TimeInterval {
        await refresh()
        let nextReset = usages.compactMap(\.resetDate?.timeIntervalSinceNow).filter { $0 > 0 }.min()
        return max(30, min(pollingInterval, (nextReset ?? .infinity) + 1))
    }

    // MARK: - Widget

    private func publishSnapshot() {
        guard sharesWithWidget, let lastUpdated else { return }
        let snapshot = UsageSnapshot(usages: usages, activeAccountID: activeAccountID, updatedAt: lastUpdated)
        do {
            try SharedStore.save(snapshot)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // App Group 컨테이너를 쓸 수 없는 빌드에서는 위젯 공유만 건너뛴다.
            Diagnostics.record("widget-snapshot-error", "\(AppGroup.identifier): \(error)")
        }
    }
}

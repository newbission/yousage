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
    @ObservationIgnored private var pollingTask: Task<Void, Never>?

    private enum Keys {
        static let activeAccountID = "activeAccountID"
        static let pollingInterval = "pollingInterval"
    }

    /// - Parameter providers: 서비스별 조회 구현체. 실제 구현이 준비되면 Mock 대신 주입한다.
    init(
        accounts: [Account] = Account.samples,
        providers: [any UsageProvider] = ProviderKind.allCases.map(MockUsageProvider.init),
        defaults: UserDefaults = .standard
    ) {
        self.accounts = accounts
        self.providers = Dictionary(providers.map { ($0.kind, $0) }, uniquingKeysWith: { _, new in new })
        self.defaults = defaults

        let storedInterval = defaults.double(forKey: Keys.pollingInterval)
        pollingInterval = storedInterval > 0 ? storedInterval : 180
        activeAccountID = defaults.string(forKey: Keys.activeAccountID).flatMap(UUID.init)
            ?? accounts.first?.id

        startPolling()
    }

    var activeUsage: AccountUsage? {
        usages.first { $0.id == activeAccountID } ?? usages.first
    }

    func usage(for account: Account) -> AccountUsage? {
        usages.first { $0.id == account.id }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let providers = providers
        let results = await withTaskGroup(of: (Account.ID, Result<AccountUsage, any Error>).self) { group in
            for account in accounts {
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
            case .success(let usage):
                updated.append(usage)
            case .failure(let error):
                failures[account.id] = error.localizedDescription
                if let previous = usage(for: account) { updated.append(previous) }
            case nil:
                break
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
        let nextReset = usages.map(\.resetDate.timeIntervalSinceNow).filter { $0 > 0 }.min()
        return max(5, min(pollingInterval, (nextReset ?? .infinity) + 1))
    }

    // MARK: - Widget

    private func publishSnapshot() {
        guard let lastUpdated else { return }
        let snapshot = UsageSnapshot(usages: usages, activeAccountID: activeAccountID, updatedAt: lastUpdated)
        do {
            try SharedStore.save(snapshot)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // App Group 이 프로비저닝되지 않은 빌드에서는 위젯 공유만 건너뛴다.
        }
    }
}

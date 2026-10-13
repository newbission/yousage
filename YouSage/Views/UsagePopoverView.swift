import SwiftUI

struct UsagePopoverView: View {
    @Environment(UsageManager.self) private var manager
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if manager.accounts.isEmpty {
                emptyState
            } else if manager.accounts.count <= 3 {
                cardList
            } else {
                // 메뉴바 창은 내용 크기에 맞춰지므로 스크롤 영역에는 높이를 명시해야 접히지 않는다.
                ScrollView { cardList }
                    .frame(height: 560)
            }
            Divider()
            footer
        }
        .frame(width: 340)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text("YouSage")
                    .font(.headline)
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task { await manager.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .symbolEffect(.rotate, isActive: manager.isRefreshing)
            }
            .disabled(manager.isRefreshing)
            .help("새로고침")

            Button(action: showSettings) {
                Image(systemName: "gearshape")
            }
            .help("설정")
        }
        .buttonStyle(.borderless)
        .padding(12)
    }

    private func showSettings() {
        openSettings()
        NSApp.activate()
    }

    private var summary: String {
        if manager.accounts.isEmpty { return "연결된 계정 없음" }
        guard let lastUpdated = manager.lastUpdated else { return "불러오는 중…" }
        let critical = manager.usages.count { $0.level == .critical }
        let caution = manager.usages.count { $0.level == .caution }
        let status = if critical > 0 {
            "\(critical)개 계정 한도 임박"
        } else if caution > 0 {
            "\(caution)개 계정 주의"
        } else {
            "모든 계정 여유"
        }
        return "\(status) · \(lastUpdated.formatted(date: .omitted, time: .shortened)) 업데이트"
    }

    // MARK: - Cards

    private var cardList: some View {
        VStack(spacing: 8) {
            ForEach(manager.accounts) { account in
                AccountCardView(
                    account: account,
                    usage: manager.usage(for: account),
                    errorMessage: manager.errors[account.id],
                    isActive: manager.activeAccountID == account.id
                ) {
                    manager.activeAccountID = account.id
                }
            }
        }
        .padding(12)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("연결된 계정 없음", systemImage: "person.crop.circle.badge.plus")
        } description: {
            Text("Claude Code 또는 Codex 에 로그인한 뒤 설정에서 계정을 추가하세요.")
        } actions: {
            Button("설정 열기", action: showSettings)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            // 연결된 서비스별 웹 사용량 페이지 바로가기 (브라우저로 열림)
            ForEach(ProviderKind.allCases.filter { kind in manager.accounts.contains { $0.provider == kind } }, id: \.self) { kind in
                Button("\(kind.displayName) 웹", systemImage: "arrow.up.right.square") {
                    openURL(kind.dashboardURL)
                }
                .help("\(kind.displayName) 사용량 페이지를 브라우저에서 엽니다")
            }
            Spacer()
            Button("종료", systemImage: "power") {
                NSApp.terminate(nil)
            }
        }
        .buttonStyle(.borderless)
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

#Preview {
    UsagePopoverView()
        .environment(UsageManager.preview)
}

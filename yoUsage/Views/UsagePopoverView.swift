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
            } else if manager.accounts.count <= 2 {
                cardList
            } else {
                // 메뉴바 창은 내용 크기에 맞춰지므로 스크롤 영역에는 높이를 명시해야 접히지 않는다.
                ScrollView { cardList }
                    .frame(height: 540)
            }
            Divider()
            footer
        }
        .frame(width: 380)
        .background(YoUsageStyle.accent.opacity(0.035))
        .tint(YoUsageStyle.accent)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            BrandBadge(size: 38)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text("yoUsage")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Text("구독 한도")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(YoUsageStyle.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(YoUsageStyle.accent.opacity(0.1), in: .capsule)
                }
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
        .padding(16)
    }

    private func showSettings() {
        openSettings()
        NSApp.activate()
    }

    private var summary: String {
        if manager.accounts.isEmpty { return "연결된 계정 없음" }
        guard let lastUpdated = manager.lastUpdated else { return "불러오는 중…" }
        let critical = manager.usages.count { UsageLevel(usedPercent: $0.usedPercent, preferences: manager.displayPreferences) == .critical }
        let caution = manager.usages.count { UsageLevel(usedPercent: $0.usedPercent, preferences: manager.displayPreferences) == .caution }
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
        VStack(spacing: 12) {
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
        .padding(16)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("연결된 계정 없음", systemImage: "person.crop.circle.badge.plus")
        } description: {
            Text("Claude Code 또는 Codex에 로그인하고 구독 계정을 연결하세요. 구독 한도와 리셋 시간을 한눈에 확인할 수 있습니다.")
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
        .font(.caption)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }
}

#Preview {
    UsagePopoverView()
        .environment(UsageManager.preview)
}

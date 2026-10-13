import SwiftUI

struct UsagePopoverView: View {
    @Environment(UsageManager.self) private var manager
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ViewThatFits(in: .vertical) {
                cardList
                ScrollView { cardList }
            }
            .frame(maxHeight: 640)
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

            Button {
                openSettings()
                NSApp.activate()
            } label: {
                Image(systemName: "gearshape")
            }
            .help("설정")
        }
        .buttonStyle(.borderless)
        .padding(12)
    }

    private var summary: String {
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

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Claude 열기", systemImage: "safari") {
                openURL(URL(string: "https://claude.ai")!)
            }
            Button("사용량 설정", systemImage: "chart.bar") {
                openURL(URL(string: "https://claude.ai/settings/usage")!)
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
        .environment(UsageManager())
}

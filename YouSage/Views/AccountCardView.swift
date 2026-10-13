import SwiftUI

struct AccountCardView: View {
    let account: Account
    let usage: AccountUsage?
    let errorMessage: String?
    let isActive: Bool
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            titleRow

            if let usage {
                gauge(for: usage)
                resetRow(for: usage)
                modelBreakdown(for: usage)
            } else if errorMessage == nil {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 12))
    }

    private var titleRow: some View {
        HStack(spacing: 6) {
            Image(systemName: account.provider.symbolName)
                .foregroundStyle(.secondary)
            Text(account.name)
                .font(.headline)
            Text(account.provider.displayName)
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.tint.opacity(0.15), in: .capsule)
                .foregroundStyle(.tint)

            Spacer()

            Button(action: onSelect) {
                Image(systemName: isActive ? "menubar.arrow.up.rectangle" : "menubar.rectangle")
                    .foregroundStyle(isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            }
            .buttonStyle(.borderless)
            .help(isActive ? "메뉴바에 표시 중" : "메뉴바에 표시")
        }
    }

    private func gauge(for usage: AccountUsage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("5시간 윈도우")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(usage.level.label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(usage.level.color)
                Text(usage.usedPercent / 100, format: .percent.precision(.fractionLength(0)))
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            // 시스템 Gauge 는 창이 비활성일 때 회색으로 바뀌므로 상태 색이 항상 보이도록 직접 그린다.
            Capsule()
                .fill(usage.level.color.opacity(0.2))
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(usage.level.color.gradient)
                            .frame(width: proxy.size.width * min(max(usage.usedPercent / 100, 0), 1))
                    }
                }
                .frame(height: 6)
                .animation(.smooth, value: usage.usedPercent)
        }
    }

    private func resetRow(for usage: AccountUsage) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.arrow.circlepath")
            ResetCountdownText(resetDate: usage.resetDate)
            Text("후 리셋")
            Spacer()
            Text(usage.resetDate, format: .dateTime.hour().minute())
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func modelBreakdown(for usage: AccountUsage) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
            ForEach(usage.modelBreakdown) { model in
                GridRow {
                    Text(model.name)
                    ProgressView(value: usage.share(of: model))
                        .tint(.secondary)
                    Text(model.tokens, format: .number.notation(.compactName))
                        .monospacedDigit()
                        .gridColumnAlignment(.trailing)
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

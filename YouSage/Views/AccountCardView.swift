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
                if !usage.additionalLimits.isEmpty {
                    additionalLimits(for: usage)
                }
            } else if errorMessage == nil {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 12))
    }

    private var titleRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: account.provider.symbolName)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(account.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(account.provider.displayName)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.tint.opacity(0.15), in: .capsule)
                        .foregroundStyle(.tint)
                        .fixedSize()
                }
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            Button(action: onSelect) {
                Image(systemName: isActive ? "menubar.arrow.up.rectangle" : "menubar.rectangle")
                    .foregroundStyle(isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            }
            .buttonStyle(.borderless)
            .help(isActive ? "메뉴바에 표시 중" : "메뉴바에 표시")
        }
    }

    /// "이메일 · 플랜"
    private var detail: String? {
        let parts = [usage?.email, usage?.plan].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
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
            UsageBar(usedPercent: usage.usedPercent)
                .frame(height: 6)
        }
    }

    @ViewBuilder
    private func resetRow(for usage: AccountUsage) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.arrow.circlepath")
            if let resetDate = usage.resetDate {
                ResetCountdownText(resetDate: resetDate)
                Text("후 리셋")
                Spacer()
                Text(resetDate, format: .dateTime.hour().minute())
            } else {
                Text("진행 중인 윈도우 없음")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func additionalLimits(for usage: AccountUsage) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 5) {
            ForEach(usage.additionalLimits) { limit in
                GridRow {
                    Text(limit.title)
                    UsageBar(usedPercent: limit.usedPercent)
                        .frame(height: 4)
                    Text(limit.usedPercent / 100, format: .percent.precision(.fractionLength(0)))
                        .monospacedDigit()
                        .gridColumnAlignment(.trailing)
                    if let resetDate = limit.resetDate {
                        Text(resetDate, format: .dateTime.month(.defaultDigits).day().hour().minute())
                            .foregroundStyle(.tertiary)
                            .gridColumnAlignment(.trailing)
                    } else {
                        Text("")
                    }
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

/// 상태 색으로 채워지는 가로 막대. 시스템 Gauge 는 창이 비활성일 때 회색으로 바뀌므로 직접 그린다.
private struct UsageBar: View {
    let usedPercent: Double

    var body: some View {
        let color = UsageLevel(usedPercent: usedPercent).color
        Capsule()
            .fill(color.opacity(0.2))
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(color.gradient)
                        .frame(width: proxy.size.width * min(max(usedPercent / 100, 0), 1))
                }
            }
            .animation(.smooth, value: usedPercent)
    }
}

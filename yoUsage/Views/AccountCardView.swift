import SwiftUI

struct AccountCardView: View {
    @Environment(\.usageDisplayPreferences) private var preferences
    let account: Account
    let usage: AccountUsage?
    let errorMessage: String?
    let isActive: Bool
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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
        .padding(18)
        .background(.background.opacity(0.7), in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(isActive ? YoUsageStyle.accent.opacity(0.35) : Color.primary.opacity(0.06), lineWidth: 1)
        }
    }

    private var titleRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: account.provider.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(account.provider == .claudeCode ? Color.orange : YoUsageStyle.accent)
                .frame(width: 34, height: 34)
                .background(.primary.opacity(0.045), in: .rect(cornerRadius: 10))

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
                Image(systemName: isActive ? "pin.fill" : "pin")
                    .foregroundStyle(isActive ? AnyShapeStyle(YoUsageStyle.accent) : AnyShapeStyle(.secondary))
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
        let level = UsageLevel(usedPercent: usage.usedPercent, preferences: preferences)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("5시간 구독 한도")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(preferences.percent(used: usage.usedPercent) / 100,
                             format: .percent.precision(.fractionLength(0)))
                            .font(.system(size: 42, weight: .semibold, design: .rounded))
                            .tracking(-1.5)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text(preferences.label)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(level.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(level.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(level.color.opacity(0.1), in: .capsule)
            }
            UsageBar(usedPercent: usage.usedPercent)
                .frame(height: 8)
                .accessibilityLabel("5시간 \(preferences.label)")
                .accessibilityValue("\(Int(preferences.percent(used: usage.usedPercent)))퍼센트")
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
        VStack(spacing: 12) {
            Divider().opacity(0.6)
            ForEach(usage.additionalLimits) { limit in
                VStack(spacing: 6) {
                    HStack {
                        Text(limit.title)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(preferences.percent(used: limit.usedPercent).rounded()))% \(preferences.label)")
                            .fontWeight(.medium)
                            .monospacedDigit()
                    }
                    UsageBar(usedPercent: limit.usedPercent)
                        .frame(height: 4)
                    if let resetDate = limit.resetDate {
                        Text("\(resetDate.formatted(.dateTime.month(.defaultDigits).day().hour().minute())) 리셋")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
        }
        .font(.caption)
    }
}

/// 상태 색으로 채워지는 가로 막대. 시스템 Gauge 는 창이 비활성일 때 회색으로 바뀌므로 직접 그린다.
private struct UsageBar: View {
    @Environment(\.usageDisplayPreferences) private var preferences
    let usedPercent: Double

    var body: some View {
        let color = UsageLevel(usedPercent: usedPercent, preferences: preferences).color
        Capsule()
            .fill(color.opacity(0.2))
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(color.gradient)
                        .frame(width: proxy.size.width * preferences.percent(used: usedPercent) / 100)
                }
            }
            .animation(.smooth, value: usedPercent)
            .animation(.smooth, value: preferences)
    }
}

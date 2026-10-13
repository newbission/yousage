import SwiftUI
import WidgetKit

@main
struct YouSageWidgetBundle: WidgetBundle {
    var body: some Widget {
        YouSageWidget()
    }
}

struct YouSageWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "YouSageWidget", provider: UsageTimelineProvider()) { entry in
            YouSageWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("YouSage")
        .description("활성 계정의 잔여 쿼터와 리셋 시간을 보여줍니다.")
        .supportedFamilies([.systemSmall])
    }
}

struct UsageEntry: TimelineEntry {
    let date: Date
    let usage: AccountUsage?
}

struct UsageTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> UsageEntry {
        UsageEntry(date: .now, usage: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (UsageEntry) -> Void) {
        let usage = SharedStore.load()?.activeUsage
        completion(UsageEntry(date: .now, usage: usage ?? (context.isPreview ? .placeholder : nil)))
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<UsageEntry>) -> Void) {
        let now = Date.now
        let usage = SharedStore.load()?.activeUsage
        var entries = [UsageEntry(date: now, usage: usage)]
        // 리셋 시각에 카운트다운 표시를 전환한다. 새 수치는 앱이 폴링 후 타임라인을 다시 로드해 반영한다.
        if let usage, usage.resetDate > now {
            entries.append(UsageEntry(date: usage.resetDate, usage: usage))
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(15 * 60))))
    }
}

struct YouSageWidgetView: View {
    let entry: UsageEntry

    var body: some View {
        if let usage = entry.usage {
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: usage.provider.symbolName)
                    Text(usage.name)
                        .lineLimit(1)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

                UsageRing(usedPercent: usage.usedPercent)
                    .overlay {
                        VStack(spacing: 0) {
                            Text(usage.remainingPercent / 100, format: .percent.precision(.fractionLength(0)))
                                .font(.title2.weight(.bold))
                                .monospacedDigit()
                            Text("남음")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                HStack(spacing: 3) {
                    Image(systemName: "clock.arrow.circlepath")
                    ResetCountdownText(resetDate: usage.resetDate, now: entry.date)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
        } else {
            ContentUnavailableView("데이터 없음", systemImage: "sparkles", description: Text("YouSage 앱을 실행해 주세요."))
        }
    }
}

#Preview(as: .systemSmall) {
    YouSageWidget()
} timeline: {
    UsageEntry(date: .now, usage: .placeholder)
}

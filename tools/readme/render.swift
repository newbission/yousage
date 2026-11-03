import AppKit
import SwiftUI
import WidgetKit
import ImageIO

// Documentation fixtures only: no authentication, requests, or shared-store writes.
struct DocumentationProvider: UsageProvider {
    let kind: ProviderKind
    func fetchUsage(for account: Account) async throws -> AccountUsage {
        sample(account, used: account.provider == .codex ? 24 : (account.name == "Work" ? 68 : 18))
    }
}

let referenceDate = Date.now
func sample(_ account: Account, used: Double) -> AccountUsage {
    AccountUsage(id: account.id, name: account.name, provider: account.provider,
                 email: "\(account.name.lowercased())@example.com", plan: account.provider == .codex ? "Plus" : "Max",
                 usedPercent: used, resetDate: referenceDate.addingTimeInterval(13200),
                 additionalLimits: [UsageLimit(id: "weekly", title: "주간", usedPercent: 36,
                                              resetDate: referenceDate.addingTimeInterval(259200))])
}

@MainActor func render<V: View>(_ view: V) -> CGImage {
    let content = view.environment(\.colorScheme, .dark)
        .environment(\.locale, Locale(identifier: "ko_KR"))
        .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
        .tint(YoUsageStyle.accent)
    let hosting = NSHostingView(rootView: content)
    let size = hosting.fittingSize
    let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                          styleMask: [.borderless], backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: .darkAqua)
    window.contentView = hosting
    hosting.frame = NSRect(origin: .zero, size: size)
    hosting.layoutSubtreeIfNeeded()
    window.displayIfNeeded()
    let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds)!
    hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
    return bitmap.cgImage!
}
func png(_ image: CGImage, _ path: String) {
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    precondition(CGImageDestinationFinalize(dest))
}

@main struct RenderDocumentation {
    @MainActor static func main() async {
        _ = NSApplication.shared
        NSApp.appearance = NSAppearance(named: .darkAqua)
        let output = CommandLine.arguments[1]
        let defaults = UserDefaults(suiteName: "com.yousage.documentation")!
        defaults.removePersistentDomain(forName: "com.yousage.documentation")
        defer { defaults.removePersistentDomain(forName: "com.yousage.documentation") }
        defaults.set(try! JSONEncoder().encode(Array(Account.samples.prefix(2))), forKey: "accounts")
        let manager = UsageManager(providers: ProviderKind.allCases.map(DocumentationProvider.init),
                                   defaults: defaults, sharesWithWidget: false)
        await manager.refresh()
        let settings = render(SettingsView().environment(manager))
        png(settings, "\(output)/settings.png")
        // Focused excerpts of the same rendered settings view (2× backing scale).
        let scale = CGFloat(settings.width) / 520
        png(settings.cropping(to: CGRect(x: 10 * scale, y: 265 * scale, width: 500 * scale, height: 390 * scale))!,
            "\(output)/settings-display.png")
        png(settings.cropping(to: CGRect(x: 10 * scale, y: 670 * scale, width: 500 * scale, height: 405 * scale))!,
            "\(output)/settings-accounts.png")
        if CommandLine.arguments.contains("--settings-only") { return }
        png(render(UsagePopoverView().environment(manager).padding(24).background(Color(red: 0.035, green: 0.075, blue: 0.10))), "\(output)/accounts.png")
        let snapshot = UsageSnapshot(usages: [sample(Account.samples[0], used: 18), sample(Account.samples[2], used: 24)],
                                     activeAccountID: Account.samples[0].id, updatedAt: referenceDate)
        let summary = shortSummary(snapshot, at: referenceDate, style: Style(color: false))
        png(render(VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 7) {
                ForEach([Color.red, Color.yellow, Color.green], id: \.self) { color in
                    Circle().fill(color.opacity(0.8)).frame(width: 9, height: 9)
                }
                Spacer()
                Text("SSH / tmux / status line").foregroundStyle(.secondary)
            }
            Text("$ yousage --short").foregroundStyle(.white)
            Text(summary).foregroundStyle(Color(red: 0.55, green: 0.96, blue: 0.79))
            Text("$ yousage title").foregroundStyle(.white)
            Text("셸 창 제목 끝에도 같은 요약을 표시합니다.").foregroundStyle(.secondary)
            Text("예시 스냅샷 · 실제 CLI 포매터 출력").font(.system(size: 11)).foregroundStyle(.secondary)
        }.font(.system(size: 14, design: .monospaced)).padding(28)
            .frame(width: 940, alignment: .leading).background(Color(red: 0.035, green: 0.075, blue: 0.10))), "\(output)/terminal.png")
        let account = Account.samples[0]
        let usage = sample(account, used: 18)
        png(render(VStack(spacing: 18) {
            YoUsageWidgetView(entry: UsageEntry(date: referenceDate, usage: usage))
                .padding(16).frame(width: 170, height: 170)
                .background(Color(red: 0.10, green: 0.16, blue: 0.18), in: .rect(cornerRadius: 24))
            Text("선택한 계정 · 잔량과 리셋 시간").font(.caption).foregroundStyle(.secondary)
        }.padding(28).background(Color(red: 0.035, green: 0.075, blue: 0.10))), "\(output)/widget.png")

        let values: [Double] = [18, 35, 50, 60, 68, 78, 85, 90]
        let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: "\(output)/quota-states.gif") as CFURL,
                                                         "com.compuserve.gif" as CFString, values.count, nil)!
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for used in values {
            let image = render(VStack(alignment: .leading, spacing: 18) {
                HStack {
                    BrandBadge(size: 32)
                    Text("yoUsage").font(.headline)
                    Spacer()
                    Image(nsImage: MenuBarGauge.image(usedPercent: used, preferences: .init(), dark: true))
                }
                AccountCardView(account: account, usage: sample(account, used: used), errorMessage: nil,
                                isActive: true, onSelect: {})
                Text("예시 데이터 · 기본 경고 기준")
                    .font(.caption2).foregroundStyle(.secondary)
            }.padding(24).frame(width: 428).background(Color(red: 0.035, green: 0.075, blue: 0.10)))
            if used == 18 { png(image, "\(output)/quota-poster.png") }
            CGImageDestinationAddImage(destination, image, [kCGImagePropertyGIFDictionary:
                [kCGImagePropertyGIFDelayTime: (used == 18 || used == 90) ? 2.0 : 0.8]] as CFDictionary)
        }
        precondition(CGImageDestinationFinalize(destination))
        print("Rendered account panel, widget view, and quota-state GIF using production SwiftUI views.")
    }
}

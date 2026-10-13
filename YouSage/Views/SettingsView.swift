import SwiftUI

struct SettingsView: View {
    @Environment(UsageManager.self) private var manager

    var body: some View {
        @Bindable var manager = manager

        Form {
            Section("새로고침") {
                Picker("자동 폴링 주기", selection: $manager.pollingInterval) {
                    Text("1분").tag(TimeInterval(60))
                    Text("3분").tag(TimeInterval(180))
                    Text("5분").tag(TimeInterval(300))
                    Text("10분").tag(TimeInterval(600))
                }
            }

            Section("메뉴바 · 위젯") {
                Picker("표시할 계정", selection: $manager.activeAccountID) {
                    ForEach(manager.accounts) { account in
                        Text("\(account.name) (\(account.provider.displayName))")
                            .tag(Optional(account.id))
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
    }
}

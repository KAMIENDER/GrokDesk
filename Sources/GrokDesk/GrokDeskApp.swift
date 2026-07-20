import SwiftUI

@main
struct GrokDeskApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var updateManager = UpdateManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .environmentObject(updateManager)
                .environment(\.locale, model.settings.appLocale)
                .preferredColorScheme(model.settings.preferredColorScheme)
                .frame(minWidth: 1060, minHeight: 680)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建对话") { model.newConversation() }
                    .keyboardShortcut("n", modifiers: [.command])
            }
            CommandGroup(after: .appInfo) {
                Button("检查更新…") { updateManager.checkForUpdates() }
            }
        }
        Settings {
            SettingsView()
                .environmentObject(model)
                .environmentObject(updateManager)
                .environment(\.locale, model.settings.appLocale)
                .preferredColorScheme(model.settings.preferredColorScheme)
                .frame(minWidth: 900, idealWidth: 1100, minHeight: 650, idealHeight: 760)
        }
    }
}

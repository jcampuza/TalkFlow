import SwiftUI

@main
struct TalkFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsWindow()
                .environmentObject(appDelegate.dependencyContainer.configurationManager)
                .environmentObject(appDelegate.dependencyContainer.historyStorage)
        }

        Window("History", id: "history") {
            HistoryWindow()
                .environmentObject(appDelegate.dependencyContainer.historyStorage)
        }
        .defaultSize(width: 600, height: 500)
    }
}

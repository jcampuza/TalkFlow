import SwiftUI

@main
struct TalkFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar apps should NOT use Window scenes - they auto-open on launch
        // Main window is created programmatically via AppDelegate.showMainWindow()

        // Settings window for Cmd+, shortcut (doesn't auto-open)
        Settings {
            SettingsWindow()
                .environment(\.configurationManager, appDelegate.dependencyContainer.configurationManager)
                .environment(\.historyStorage, appDelegate.dependencyContainer.historyStorage)
        }
    }
}

import SwiftUI

@main
struct TalkFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar app - main window is created programmatically via AppDelegate.showMainWindow()
        // Settings is integrated into the main window sidebar

        // Empty Settings scene to satisfy SwiftUI but we handle Cmd+, in AppDelegate
        Settings {
            EmptyView()
        }
    }
}

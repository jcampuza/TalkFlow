import SwiftUI

struct SettingsWindow: View {
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(SettingsTab.general)

            AudioSettingsView()
                .tabItem {
                    Label("Audio", systemImage: "waveform")
                }
                .tag(SettingsTab.audio)

            TranscriptionSettingsView()
                .tabItem {
                    Label("Transcription", systemImage: "text.bubble")
                }
                .tag(SettingsTab.transcription)

            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
                .tag(SettingsTab.appearance)
        }
        .frame(width: 500, height: 350)
    }
}

enum SettingsTab: Hashable {
    case general
    case audio
    case transcription
    case appearance
}

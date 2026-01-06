import SwiftUI

/// Main window view that shows History as the primary view with Settings as a tab
struct MainWindowView: View {
    @Environment(\.historyStorage) private var historyStorage
    @Environment(\.configurationManager) private var configurationManager
    var onboardingManager: OnboardingManager

    @State private var selectedTab: MainTab = .history

    enum MainTab: String, CaseIterable {
        case history = "History"
        case dictionary = "Dictionary"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .history:
                return "clock.arrow.circlepath"
            case .dictionary:
                return "text.book.closed"
            case .settings:
                return "gearshape"
            }
        }
    }

    var body: some View {
        Group {
            if onboardingManager.shouldShowOnboarding {
                OnboardingView(onboardingManager: onboardingManager)
            } else {
                mainContent
            }
        }
    }

    private var mainContent: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            detailContent
        }
        .frame(minWidth: 700, minHeight: 500)
    }

    private var sidebarContent: some View {
        List(MainTab.allCases, id: \.self, selection: $selectedTab) { tab in
            Label(tab.rawValue, systemImage: tab.icon)
                .tag(tab)
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 150, ideal: 180, max: 220)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedTab {
        case .history:
            HistoryContentView()
        case .dictionary:
            DictionaryContentView()
        case .settings:
            SettingsContentView()
        }
    }
}

/// History content view (extracted from HistoryWindow)
struct HistoryContentView: View {
    @Environment(\.historyStorage) private var historyStorage
    @State private var searcher = HistorySearcher()
    @State private var showingDeleteConfirmation = false
    @State private var recordToDelete: TranscriptionRecord?
    @State private var copiedRecordId: String?
    @State private var allRecords: [TranscriptionRecord] = []

    var body: some View {
        VStack(spacing: 0) {
            // Header with search
            HStack {
                Text("Transcription History")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Search...", text: $searcher.searchText)
                        .textFieldStyle(.plain)
                        .frame(width: 200)

                    if !searcher.searchText.isEmpty {
                        Button(action: { searcher.clearSearch() }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            .padding()

            Divider()

            // List
            if displayedRecords.isEmpty {
                emptyStateView
            } else {
                List(displayedRecords) { record in
                    HistoryRowView(
                        record: record,
                        isCopied: copiedRecordId == record.id,
                        onCopy: { copyToClipboard(record) },
                        onDelete: { confirmDelete(record) }
                    )
                }
                .listStyle(.inset)
            }
        }
        .task {
            if let storage = historyStorage {
                searcher.setStorage(storage)
                allRecords = await storage.fetchAll()
            }
        }
        .alert("Delete Transcription?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                recordToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let record = recordToDelete {
                    Task {
                        try? await historyStorage?.delete(record)
                        if let storage = historyStorage {
                            allRecords = await storage.fetchAll()
                        }
                    }
                    recordToDelete = nil
                }
            }
        } message: {
            Text("This transcription will be permanently deleted.")
        }
    }

    private var displayedRecords: [TranscriptionRecord] {
        if searcher.searchText.isEmpty {
            return allRecords
        } else {
            return searcher.searchResults
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.bubble")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            if searcher.searchText.isEmpty {
                Text("No Transcriptions Yet")
                    .font(.headline)
                Text("Your voice transcriptions will appear here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("No Results")
                    .font(.headline)
                Text("No transcriptions match \"\(searcher.searchText)\"")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func copyToClipboard(_ record: TranscriptionRecord) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(record.text, forType: .string)

        copiedRecordId = record.id

        // Reset copied state after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if copiedRecordId == record.id {
                copiedRecordId = nil
            }
        }
    }

    private func confirmDelete(_ record: TranscriptionRecord) {
        recordToDelete = record
        showingDeleteConfirmation = true
    }
}

/// Settings content view (wraps the existing settings tabs)
struct SettingsContentView: View {
    @State private var selectedSettingsTab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()

            Divider()

            // Settings tabs
            TabView(selection: $selectedSettingsTab) {
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
            .padding()
        }
    }
}

/// Dictionary content view wrapper
struct DictionaryContentView: View {
    @Environment(\.dictionaryManager) private var dictionaryManager

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Custom Dictionary")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()

            Divider()

            // Dictionary content
            if let manager = dictionaryManager {
                DictionaryView(manager: manager)
            } else {
                Text("Dictionary unavailable")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct MainWindowView_Previews: PreviewProvider {
    static var previews: some View {
        MainWindowView(onboardingManager: OnboardingManager())
            .environment(\.historyStorage, HistoryStorage())
            .environment(\.configurationManager, ConfigurationManager())
    }
}
#endif

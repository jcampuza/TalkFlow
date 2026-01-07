import SwiftUI

// MARK: - Main Tab

enum MainTab: String, CaseIterable, Identifiable {
    case history = "History"
    case dictionary = "Dictionary"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .history:
            return "waveform"
        case .dictionary:
            return "character.book.closed"
        }
    }
}

// MARK: - Settings Tab Enum (moved from SettingsWindow)

enum SettingsTab: Hashable {
    case general
    case audio
    case transcription
    case appearance
}

// MARK: - Main Window View

struct MainWindowView: View {
    @Environment(\.historyStorage) private var historyStorage
    @Environment(\.configurationManager) private var configurationManager
    var onboardingManager: OnboardingManager

    @State private var selectedTab: MainTab = .history
    @State private var showSettings = false

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
        HStack(spacing: 0) {
            // Custom sidebar
            sidebarView

            // Divider between sidebar and content
            Rectangle()
                .fill(DesignConstants.dividerColor)
                .frame(width: 1)

            // Content area with inset styling
            contentAreaView
        }
        .frame(minWidth: 600, minHeight: 400)
        .background(DesignConstants.sidebarBackground)
        .environment(\.colorScheme, .light)
        .tint(DesignConstants.accentColor)  // Apply brand accent to system controls
    }

    // MARK: - Sidebar

    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App branding header
            brandingHeader

            Spacer().frame(height: 20)

            // Main navigation items
            ForEach(MainTab.allCases) { tab in
                sidebarItem(
                    title: tab.rawValue,
                    icon: tab.icon,
                    isSelected: selectedTab == tab && !showSettings
                ) {
                    selectedTab = tab
                    showSettings = false
                }
            }

            Spacer()

            // Bottom divider
            Rectangle()
                .fill(DesignConstants.dividerColor)
                .frame(height: 1)
                .padding(.horizontal, DesignConstants.sidebarPadding)

            Spacer().frame(height: 12)

            // Settings at bottom
            sidebarItem(
                title: "Settings",
                icon: "gearshape",
                isSelected: showSettings
            ) {
                showSettings = true
            }

            Spacer().frame(height: 16)
        }
        .frame(width: DesignConstants.sidebarWidth)
        .background(DesignConstants.sidebarBackground)
    }

    private var brandingHeader: some View {
        HStack(spacing: 10) {
            // App icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 32, height: 32)

            Text("TalkFlow")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(DesignConstants.primaryText)
        }
        .padding(.horizontal, DesignConstants.sidebarPadding)
        .padding(.top, 16)
    }

    private func sidebarItem(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: DesignConstants.iconSize, weight: .regular))
                    .foregroundColor(isSelected ? DesignConstants.accentColor : DesignConstants.secondaryText)
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? DesignConstants.primaryText : DesignConstants.secondaryText)

                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: DesignConstants.sidebarItemHeight)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: DesignConstants.itemCornerRadius)
                    .fill(isSelected ? DesignConstants.selectedItemBackground : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DesignConstants.sidebarPadding)
    }

    // MARK: - Content Area

    private var contentAreaView: some View {
        ZStack {
            // Background
            DesignConstants.contentBackground

            // Inset content with rounded corners
            RoundedRectangle(cornerRadius: DesignConstants.contentCornerRadius)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                .padding(12)

            // Actual content - force light color scheme for all system controls
            Group {
                if showSettings {
                    SettingsContentView()
                } else {
                    switch selectedTab {
                    case .history:
                        HistoryContentView()
                    case .dictionary:
                        DictionaryContentView()
                    }
                }
            }
            .environment(\.colorScheme, .light)
            .clipShape(RoundedRectangle(cornerRadius: DesignConstants.contentCornerRadius))
            .padding(12)
        }
    }
}

// MARK: - Quick Start Tip Card

struct QuickStartTipCard: View {
    @Environment(\.configurationManager) private var configurationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text("Hold")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(DesignConstants.primaryText)

                shortcutDisplay

                Text("to dictate")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(DesignConstants.primaryText)
            }

            Text("Press and hold your trigger key to record, then release to transcribe and paste the text.")
                .font(.system(size: 13))
                .foregroundColor(DesignConstants.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignConstants.tipCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(DesignConstants.tipCardBorder, lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private var shortcutDisplay: some View {
        let shortcut = configurationManager?.configuration.triggerShortcut ?? .rightCommand

        HStack(spacing: 2) {
            KeyCapView(text: shortcut.displayName)
        }
    }
}

struct KeyCapView: View {
    var text: String?
    var symbol: String?

    var body: some View {
        Group {
            if let symbol = symbol {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
            } else if let text = text {
                Text(text)
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .foregroundColor(DesignConstants.primaryText)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(DesignConstants.keyCapBackground)
                .shadow(color: Color.black.opacity(0.1), radius: 0.5, x: 0, y: 0.5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(DesignConstants.dividerColor, lineWidth: 0.5)
        )
    }
}

// MARK: - History Content View

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
            headerView

            Rectangle()
                .fill(DesignConstants.dividerColor)
                .frame(height: 1)

            // Quick start tip card (always visible)
            QuickStartTipCard()
                .padding(16)

            Rectangle()
                .fill(DesignConstants.dividerColor)
                .frame(height: 1)

            // List or empty state
            if displayedRecords.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(displayedRecords) { record in
                            HistoryRowView(
                                record: record,
                                isCopied: copiedRecordId == record.id,
                                onCopy: { copyToClipboard(record) },
                                onDelete: { confirmDelete(record) }
                            )

                            if record.id != displayedRecords.last?.id {
                                Rectangle()
                                    .fill(DesignConstants.dividerColor)
                                    .frame(height: 1)
                                    .padding(.leading, 16)
                            }
                        }
                    }
                }
            }
        }
        .background(Color.white)
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

    private var headerView: some View {
        HStack {
            Text("Transcription History")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(DesignConstants.primaryText)

            Spacer()

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(DesignConstants.secondaryText)
                    .font(.system(size: 14))

                TextField("Search...", text: $searcher.searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(DesignConstants.primaryText)
                    .frame(width: 180)

                if !searcher.searchText.isEmpty {
                    Button(action: { searcher.clearSearch() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(DesignConstants.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(DesignConstants.searchBarBackground)
            )
        }
        .padding(16)
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
            Image(systemName: "waveform.badge.mic")
                .font(.system(size: 56))
                .foregroundColor(DesignConstants.tertiaryText)

            if searcher.searchText.isEmpty {
                Text("No Transcriptions Yet")
                    .font(.headline)
                    .foregroundColor(DesignConstants.primaryText)

                Text("Hold your trigger key to record and transcribe.\nYour transcriptions will appear here.")
                    .font(.subheadline)
                    .foregroundColor(DesignConstants.secondaryText)
                    .multilineTextAlignment(.center)
            } else {
                Text("No Results")
                    .font(.headline)
                    .foregroundColor(DesignConstants.primaryText)

                Text("No transcriptions match \"\(searcher.searchText)\"")
                    .font(.subheadline)
                    .foregroundColor(DesignConstants.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func copyToClipboard(_ record: TranscriptionRecord) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(record.text, forType: .string)

        copiedRecordId = record.id

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

// MARK: - History Row View

struct HistoryRowView: View {
    let record: TranscriptionRecord
    let isCopied: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timestamp
            Text(record.relativeTimestamp)
                .font(.system(size: 13))
                .foregroundColor(DesignConstants.secondaryText)
                .frame(width: 90, alignment: .leading)

            // Full transcription text
            Text(record.text)
                .font(.system(size: 14))
                .foregroundColor(DesignConstants.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            // Action buttons (always present, opacity changes on hover)
            HStack(spacing: 8) {
                Button(action: onCopy) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 13))
                        .foregroundColor(isCopied ? .green : DesignConstants.secondaryText)
                }
                .buttonStyle(.plain)
                .help(isCopied ? "Copied!" : "Copy to clipboard")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundColor(DesignConstants.secondaryText)
                }
                .buttonStyle(.plain)
                .help("Delete transcription")
            }
            .opacity(isHovered ? 1 : 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isHovered ? DesignConstants.hoverBackground : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Dictionary Content View

struct DictionaryContentView: View {
    @Environment(\.dictionaryManager) private var dictionaryManager

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Custom Dictionary")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignConstants.primaryText)
                Spacer()
            }
            .padding(16)

            Rectangle()
                .fill(DesignConstants.dividerColor)
                .frame(height: 1)

            // Dictionary content
            if let manager = dictionaryManager {
                DictionaryView(manager: manager)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "text.book.closed")
                        .font(.system(size: 56))
                        .foregroundColor(DesignConstants.tertiaryText)

                    Text("Dictionary unavailable")
                        .foregroundColor(DesignConstants.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.white)
    }
}

// MARK: - Settings Content View

struct SettingsContentView: View {
    @State private var selectedSettingsTab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 0) {
            // Header with tab picker
            VStack(spacing: 12) {
                HStack {
                    Text("Settings")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignConstants.primaryText)
                    Spacer()
                }

                // Horizontal tab picker
                HStack(spacing: 0) {
                    settingsTabButton(tab: .general, title: "General", icon: "gearshape")
                    settingsTabButton(tab: .audio, title: "Audio", icon: "waveform")
                    settingsTabButton(tab: .transcription, title: "Transcription", icon: "text.bubble")
                    settingsTabButton(tab: .appearance, title: "Appearance", icon: "paintbrush")
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(DesignConstants.searchBarBackground)
                )
            }
            .padding(16)

            Rectangle()
                .fill(DesignConstants.dividerColor)
                .frame(height: 1)

            // Settings content
            ScrollView {
                Group {
                    switch selectedSettingsTab {
                    case .general:
                        GeneralSettingsView()
                    case .audio:
                        AudioSettingsView()
                    case .transcription:
                        TranscriptionSettingsView()
                    case .appearance:
                        AppearanceSettingsView()
                    }
                }
                .padding(16)
            }
        }
        .background(Color.white)
    }

    private func settingsTabButton(tab: SettingsTab, title: String, icon: String) -> some View {
        Button(action: { selectedSettingsTab = tab }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(selectedSettingsTab == tab ? DesignConstants.accentColor : DesignConstants.secondaryText)
                Text(title)
                    .font(.system(size: 13, weight: selectedSettingsTab == tab ? .medium : .regular))
                    .foregroundColor(selectedSettingsTab == tab ? DesignConstants.primaryText : DesignConstants.secondaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedSettingsTab == tab ? Color.white : Color.clear)
                    .shadow(color: selectedSettingsTab == tab ? Color.black.opacity(0.06) : Color.clear, radius: 1, x: 0, y: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG
struct MainWindowView_Previews: PreviewProvider {
    static var previews: some View {
        MainWindowView(onboardingManager: OnboardingManager())
            .environment(\.historyStorage, HistoryStorage())
            .environment(\.configurationManager, ConfigurationManager())
            .frame(width: 800, height: 600)
    }
}
#endif

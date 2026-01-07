import Foundation
@preconcurrency import WhisperKit

/// Represents a local Whisper model that can be downloaded
struct LocalWhisperModel: Identifiable, Sendable {
    let id: String
    let displayName: String
    let sizeDescription: String
    let sizeBytes: Int64
    let qualityDescription: String

    static let tiny = LocalWhisperModel(
        id: "openai_whisper-tiny",
        displayName: "Tiny",
        sizeDescription: "~40 MB",
        sizeBytes: 40 * 1024 * 1024,
        qualityDescription: "Fast, basic quality"
    )

    static let small = LocalWhisperModel(
        id: "openai_whisper-small",
        displayName: "Small",
        sizeDescription: "~250 MB",
        sizeBytes: 250 * 1024 * 1024,
        qualityDescription: "Balanced quality and size"
    )

    static let largeTurbo = LocalWhisperModel(
        id: "openai_whisper-large-v3_turbo",
        displayName: "Large v3 Turbo",
        sizeDescription: "~950 MB",
        sizeBytes: 950 * 1024 * 1024,
        qualityDescription: "Best quality"
    )

    /// All available models
    static let allModels: [LocalWhisperModel] = [tiny, small, largeTurbo]

    /// Get model by ID
    static func model(for id: String) -> LocalWhisperModel? {
        allModels.first { $0.id == id }
    }
}

/// Represents the current download state
enum ModelDownloadState: Sendable {
    case idle
    case downloading(modelId: String, progress: Double)
    case completed(modelId: String)
    case failed(modelId: String, error: String)
}

/// Manages local Whisper model downloads, storage, and lifecycle
@Observable
final class ModelManager: @unchecked Sendable {
    /// Current download state
    @MainActor private(set) var downloadState: ModelDownloadState = .idle

    /// Set of downloaded model IDs
    @MainActor private(set) var downloadedModels: Set<String> = []

    /// Whether a download is currently in progress
    @MainActor var isDownloading: Bool {
        if case .downloading = downloadState {
            return true
        }
        return false
    }

    /// Current download progress (0.0 to 1.0)
    @MainActor var downloadProgress: Double {
        if case .downloading(_, let progress) = downloadState {
            return progress
        }
        return 0.0
    }

    /// ID of model currently being downloaded
    @MainActor var downloadingModelId: String? {
        if case .downloading(let modelId, _) = downloadState {
            return modelId
        }
        return nil
    }

    private let fileManager = FileManager.default
    private var downloadTask: Task<Void, Error>?

    init() {
        Task { @MainActor in
            await scanForDownloadedModels()
        }
    }

    /// Scans the WhisperKit cache directory for downloaded models
    @MainActor
    func scanForDownloadedModels() async {
        var found: Set<String> = []

        for model in LocalWhisperModel.allModels {
            if await checkModelExists(model.id) {
                found.insert(model.id)
            }
        }

        downloadedModels = found
        Logger.shared.debug("Found \(found.count) downloaded models: \(found)", component: "ModelManager")
    }

    /// Checks if a specific model is downloaded
    func isModelDownloaded(_ modelId: String) async -> Bool {
        await checkModelExists(modelId)
    }

    /// Gets the path where a model is stored
    func getModelPath(for modelId: String) async -> String? {
        // WhisperKit stores models in its own cache directory
        // Return nil to let WhisperKit use its default path
        return nil
    }

    /// Downloads a model with progress updates
    @MainActor
    func downloadModel(_ modelId: String, progress: @escaping @Sendable (Double) -> Void) async throws {
        guard !isDownloading else {
            throw TranscriptionError.downloadFailed("Another download is in progress")
        }

        guard let model = LocalWhisperModel.model(for: modelId) else {
            throw TranscriptionError.downloadFailed("Unknown model: \(modelId)")
        }

        // Check disk space
        try await checkDiskSpace(for: model)

        // Clean up any partial downloads
        await cleanupPartialDownload(modelId)

        Logger.shared.info("Starting download of model: \(modelId)", component: "ModelManager")
        downloadState = .downloading(modelId: modelId, progress: 0.0)

        downloadTask = Task {
            do {
                // WhisperKit handles the download when initialized with download: true
                // We use a simple progress simulation since WhisperKit doesn't expose download progress directly
                // The actual download happens during WhisperKit initialization

                // Start progress animation
                let progressTask = Task {
                    var simulatedProgress = 0.0
                    while simulatedProgress < 0.9 {
                        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                        simulatedProgress += 0.05
                        await MainActor.run {
                            self.downloadState = .downloading(modelId: modelId, progress: simulatedProgress)
                            progress(simulatedProgress)
                        }
                    }
                }

                // Initialize WhisperKit which will trigger download
                Logger.shared.info("Initializing WhisperKit for model download: \(modelId)", component: "ModelManager")
                _ = try await WhisperKit(
                    model: modelId,
                    verbose: true,
                    logLevel: .debug,
                    prewarm: false,
                    load: false,
                    download: true
                )
                Logger.shared.info("WhisperKit initialization completed for: \(modelId)", component: "ModelManager")

                // Cancel the progress simulation
                progressTask.cancel()

                // Verify download succeeded
                let modelExists = await checkModelExists(modelId)
                Logger.shared.info("Model exists check for \(modelId): \(modelExists)", component: "ModelManager")
                guard modelExists else {
                    throw TranscriptionError.downloadFailed("Model files not found after download")
                }

                await MainActor.run {
                    self.downloadedModels.insert(modelId)
                    self.downloadState = .completed(modelId: modelId)
                    progress(1.0)
                }

                Logger.shared.info("Model download completed: \(modelId)", component: "ModelManager")

            } catch is CancellationError {
                await MainActor.run {
                    self.downloadState = .idle
                }
                await cleanupPartialDownload(modelId)
                Logger.shared.info("Model download cancelled: \(modelId)", component: "ModelManager")
                throw TranscriptionError.downloadFailed("Download cancelled")

            } catch {
                await MainActor.run {
                    self.downloadState = .failed(modelId: modelId, error: error.localizedDescription)
                }
                await cleanupPartialDownload(modelId)
                Logger.shared.error("Model download failed: \(error)", component: "ModelManager")
                throw TranscriptionError.downloadFailed(error.localizedDescription)
            }
        }

        try await downloadTask?.value
    }

    /// Cancels the current download
    @MainActor
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        if case .downloading(let modelId, _) = downloadState {
            downloadState = .idle
            Task {
                await cleanupPartialDownload(modelId)
            }
        }
    }

    /// Deletes a downloaded model
    @MainActor
    func deleteModel(_ modelId: String) async throws {
        guard downloadedModels.contains(modelId) else {
            Logger.shared.warning("Attempted to delete non-existent model: \(modelId)", component: "ModelManager")
            return
        }

        // Get the model folder path
        let modelFolder = getWhisperKitModelFolder(for: modelId)

        if let folder = modelFolder, fileManager.fileExists(atPath: folder) {
            do {
                try fileManager.removeItem(atPath: folder)
                downloadedModels.remove(modelId)
                Logger.shared.info("Deleted model: \(modelId)", component: "ModelManager")
            } catch {
                Logger.shared.error("Failed to delete model \(modelId): \(error)", component: "ModelManager")
                throw TranscriptionError.downloadFailed("Failed to delete model: \(error.localizedDescription)")
            }
        } else {
            // Model folder not found, just remove from tracked set
            downloadedModels.remove(modelId)
            Logger.shared.warning("Model folder not found for \(modelId), removing from tracked set", component: "ModelManager")
        }
    }

    /// Resets download state to idle
    @MainActor
    func resetDownloadState() {
        downloadState = .idle
    }

    // MARK: - Private Methods

    /// Checks if a model exists on disk
    private func checkModelExists(_ modelId: String) async -> Bool {
        guard let modelFolder = getWhisperKitModelFolder(for: modelId) else {
            Logger.shared.debug("No model folder found for: \(modelId)", component: "ModelManager")
            return false
        }

        Logger.shared.debug("Checking model folder: \(modelFolder)", component: "ModelManager")

        // Check if the folder exists and contains model files
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: modelFolder, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            Logger.shared.debug("Model folder does not exist or is not a directory: \(modelFolder)", component: "ModelManager")
            return false
        }

        // Check for key model files
        let requiredFiles = ["MelSpectrogram.mlmodelc", "AudioEncoder.mlmodelc", "TextDecoder.mlmodelc"]
        for file in requiredFiles {
            let filePath = (modelFolder as NSString).appendingPathComponent(file)
            if !fileManager.fileExists(atPath: filePath) {
                Logger.shared.debug("Required file missing: \(filePath)", component: "ModelManager")
                return false
            }
        }

        Logger.shared.debug("All required model files found for: \(modelId)", component: "ModelManager")
        return true
    }

    /// Gets the WhisperKit model folder path for a model
    private func getWhisperKitModelFolder(for modelId: String) -> String? {
        // WhisperKit stores models in different locations depending on whether the app is sandboxed
        // Sandboxed apps: ~/Library/Containers/<bundle-id>/Data/Documents/huggingface/models/argmaxinc/whisperkit-coreml/
        // Non-sandboxed: ~/Library/Caches/com.argmax.whisperkit/ or ~/Library/Caches/huggingface/hub/

        // First, check the sandboxed Documents location (used when app is sandboxed)
        // FileManager.default.urls returns the sandboxed path automatically
        if let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let sandboxedPath = documentsDir
                .appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml/\(modelId)")
                .path
            Logger.shared.debug("Checking sandboxed path: \(sandboxedPath)", component: "ModelManager")
            if fileManager.fileExists(atPath: sandboxedPath) {
                Logger.shared.debug("Found model at sandboxed path", component: "ModelManager")
                return sandboxedPath
            }
        }

        let homeDir = fileManager.homeDirectoryForCurrentUser

        // Check standard WhisperKit cache location
        let standardPath = homeDir.appendingPathComponent("Library/Caches/com.argmax.whisperkit/\(modelId)").path
        Logger.shared.debug("Checking standard path: \(standardPath)", component: "ModelManager")
        if fileManager.fileExists(atPath: standardPath) {
            Logger.shared.debug("Found model at standard path", component: "ModelManager")
            return standardPath
        }

        // Check HuggingFace cache (non-sandboxed)
        let hfCachePath = homeDir.appendingPathComponent("Library/Caches/huggingface/hub").path
        Logger.shared.debug("Checking HuggingFace cache: \(hfCachePath)", component: "ModelManager")
        if fileManager.fileExists(atPath: hfCachePath) {
            // Search for the model in HuggingFace cache
            if let modelPath = findModelInHFCache(modelId: modelId, hfCachePath: hfCachePath) {
                Logger.shared.debug("Found model in HuggingFace cache: \(modelPath)", component: "ModelManager")
                return modelPath
            }
        }

        // Return sandboxed path as default (this is where WhisperKit will download to)
        if let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let defaultPath = documentsDir
                .appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml/\(modelId)")
                .path
            Logger.shared.debug("Model not found, returning sandboxed path as default: \(defaultPath)", component: "ModelManager")
            return defaultPath
        }

        Logger.shared.debug("Model not found, returning nil", component: "ModelManager")
        return nil
    }

    /// Searches for a model in the HuggingFace cache directory
    private func findModelInHFCache(modelId: String, hfCachePath: String) -> String? {
        let whisperKitRepo = "models--argmaxinc--whisperkit-coreml"
        let repoPath = (hfCachePath as NSString).appendingPathComponent(whisperKitRepo)

        guard fileManager.fileExists(atPath: repoPath) else {
            return nil
        }

        let snapshotsPath = (repoPath as NSString).appendingPathComponent("snapshots")
        guard let snapshots = try? fileManager.contentsOfDirectory(atPath: snapshotsPath) else {
            return nil
        }

        // Search each snapshot for the model
        for snapshot in snapshots {
            let modelPath = (snapshotsPath as NSString)
                .appendingPathComponent(snapshot)
                .appending("/\(modelId)")

            if fileManager.fileExists(atPath: modelPath) {
                return modelPath
            }
        }

        return nil
    }

    /// Checks available disk space before download
    private func checkDiskSpace(for model: LocalWhisperModel) async throws {
        let homeDir = fileManager.homeDirectoryForCurrentUser

        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: homeDir.path)
            if let freeSpace = attributes[.systemFreeSize] as? Int64 {
                // Require at least 1.5x the model size for safety
                let requiredSpace = Int64(Double(model.sizeBytes) * 1.5)
                if freeSpace < requiredSpace {
                    throw TranscriptionError.insufficientDiskSpace(required: requiredSpace, available: freeSpace)
                }
            }
        } catch let error as TranscriptionError {
            throw error
        } catch {
            Logger.shared.warning("Could not check disk space: \(error)", component: "ModelManager")
            // Continue anyway if we can't check
        }
    }

    /// Cleans up partial download files
    private func cleanupPartialDownload(_ modelId: String) async {
        // WhisperKit handles its own cleanup, but we can try to clean the folder if it exists
        if let modelFolder = getWhisperKitModelFolder(for: modelId) {
            try? fileManager.removeItem(atPath: modelFolder)
        }
        Logger.shared.debug("Cleaned up partial download for \(modelId)", component: "ModelManager")
    }
}

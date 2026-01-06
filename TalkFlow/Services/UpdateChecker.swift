import Foundation

final class UpdateChecker {
    private let owner: String
    private let repo: String
    private let currentVersion: String

    private let cacheKey = "lastUpdateCheck"
    private let cacheExpirationSeconds: TimeInterval = 24 * 60 * 60 // 24 hours

    init(owner: String = "josephcampuzano", repo: String = "TalkFlow") {
        self.owner = owner
        self.repo = repo
        self.currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    func checkForUpdates() async -> UpdateStatus {
        // Check cache
        if let cachedResult = getCachedResult() {
            return cachedResult
        }

        do {
            let latestVersion = try await fetchLatestVersion()
            let status = compareVersions(current: currentVersion, latest: latestVersion)

            // Cache the result
            cacheResult(status)

            return status
        } catch {
            Logger.shared.warning("Update check failed: \(error.localizedDescription)", component: "UpdateChecker")
            return .checkFailed
        }
    }

    private func fetchLatestVersion() async throws -> String {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw UpdateCheckError.requestFailed
        }

        struct Release: Decodable {
            let tag_name: String
        }

        let release = try JSONDecoder().decode(Release.self, from: data)

        // Remove 'v' prefix if present
        return release.tag_name.hasPrefix("v")
            ? String(release.tag_name.dropFirst())
            : release.tag_name
    }

    private func compareVersions(current: String, latest: String) -> UpdateStatus {
        let currentParts = current.split(separator: ".").compactMap { Int($0) }
        let latestParts = latest.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(currentParts.count, latestParts.count) {
            let currentPart = i < currentParts.count ? currentParts[i] : 0
            let latestPart = i < latestParts.count ? latestParts[i] : 0

            if latestPart > currentPart {
                return .updateAvailable(version: latest)
            } else if currentPart > latestPart {
                return .upToDate
            }
        }

        return .upToDate
    }

    private func getCachedResult() -> UpdateStatus? {
        guard let cached = UserDefaults.standard.dictionary(forKey: cacheKey),
              let timestamp = cached["timestamp"] as? TimeInterval,
              let statusRaw = cached["status"] as? String else {
            return nil
        }

        // Check if cache is expired
        if Date().timeIntervalSince1970 - timestamp > cacheExpirationSeconds {
            return nil
        }

        switch statusRaw {
        case "upToDate":
            return .upToDate
        case let status where status.hasPrefix("updateAvailable:"):
            let version = String(status.dropFirst("updateAvailable:".count))
            return .updateAvailable(version: version)
        default:
            return nil
        }
    }

    private func cacheResult(_ status: UpdateStatus) {
        var statusRaw: String

        switch status {
        case .upToDate:
            statusRaw = "upToDate"
        case .updateAvailable(let version):
            statusRaw = "updateAvailable:\(version)"
        case .checkFailed:
            return // Don't cache failures
        }

        let cached: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "status": statusRaw
        ]

        UserDefaults.standard.set(cached, forKey: cacheKey)
    }
}

enum UpdateStatus: Sendable {
    case upToDate
    case updateAvailable(version: String)
    case checkFailed
}

enum UpdateCheckError: Error, Sendable {
    case requestFailed
}

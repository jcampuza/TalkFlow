import SwiftUI
import Combine

enum IndicatorState: Equatable {
    case idle
    case recording
    case warning
    case processing
    case success
    case error(String)
    case noSpeech
    case permissionRequired

    var color: Color {
        switch self {
        case .idle:
            return .gray
        case .recording:
            return .red
        case .warning:
            return .red
        case .processing:
            return .purple
        case .success:
            return .green
        case .error:
            return .red
        case .noSpeech:
            return .orange
        case .permissionRequired:
            return .orange
        }
    }

    var icon: String {
        switch self {
        case .idle:
            return "mic.fill"
        case .recording, .warning:
            return "waveform"
        case .processing:
            return "ellipsis"
        case .success:
            return "checkmark"
        case .error:
            return "exclamationmark.triangle.fill"
        case .noSpeech:
            return "speaker.slash.fill"
        case .permissionRequired:
            return "lock.fill"
        }
    }

    var shouldPulse: Bool {
        switch self {
        case .recording, .warning, .permissionRequired:
            return true
        default:
            return false
        }
    }

    var pulseSpeed: Double {
        switch self {
        case .warning:
            return 0.3
        case .recording:
            return 0.8
        case .permissionRequired:
            return 1.5
        default:
            return 1.0
        }
    }

    var isTransient: Bool {
        switch self {
        case .success, .error, .noSpeech:
            return true
        default:
            return false
        }
    }

    var isPersistent: Bool {
        switch self {
        case .permissionRequired:
            return true
        default:
            return false
        }
    }
}

final class IndicatorStateManager: ObservableObject {
    @Published var state: IndicatorState = .idle

    private var hideTimer: Timer?

    func showSuccess() {
        state = .success
        scheduleHide()
    }

    func showError(_ message: String) {
        state = .error(message)
        scheduleHide()
    }

    func showNoSpeech() {
        state = .noSpeech
        scheduleHide()
    }

    func showPermissionRequired() {
        hideTimer?.invalidate()
        hideTimer = nil
        state = .permissionRequired
    }

    func clearPermissionRequired() {
        if state == .permissionRequired {
            state = .idle
        }
    }

    private func scheduleHide() {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            // Don't hide if we're in a persistent state
            if self?.state.isPersistent == false {
                self?.state = .idle
            }
        }
    }
}

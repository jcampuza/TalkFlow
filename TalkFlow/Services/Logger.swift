import Foundation
import os.log

final class Logger: @unchecked Sendable {
    static let shared = Logger()

    private let osLog: OSLog
    private let fileHandle: FileHandle?
    private let dateFormatter: DateFormatter
    private let logQueue = DispatchQueue(label: "com.talkflow.logger", qos: .utility)

    private init() {
        osLog = OSLog(subsystem: "com.josephcampuzano.TalkFlow", category: "General")

        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        // Setup file logging
        fileHandle = Logger.setupLogFile()
    }

    deinit {
        fileHandle?.closeFile()
    }

    private static func setupLogFile() -> FileHandle? {
        let logDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Logs")
            .appendingPathComponent("TalkFlow")

        guard let logDir = logDir else { return nil }

        // Create directory if needed
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)

        // Clean up old logs (keep last 7 days)
        cleanOldLogs(in: logDir)

        // Create today's log file
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fileName = "talkflow-\(dateFormatter.string(from: Date())).log"
        let logFile = logDir.appendingPathComponent(fileName)

        // Create file if it doesn't exist
        if !FileManager.default.fileExists(atPath: logFile.path) {
            FileManager.default.createFile(atPath: logFile.path, contents: nil)
        }

        return try? FileHandle(forWritingTo: logFile)
    }

    private static func cleanOldLogs(in directory: URL) {
        let fileManager = FileManager.default
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -7, to: Date())!

        guard let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey]) else {
            return
        }

        for file in contents {
            guard let attributes = try? file.resourceValues(forKeys: [.creationDateKey]),
                  let creationDate = attributes.creationDate,
                  creationDate < cutoffDate else {
                continue
            }

            try? fileManager.removeItem(at: file)
        }
    }

    func debug(_ message: String, component: String) {
        log(level: .debug, message: message, component: component)
    }

    func info(_ message: String, component: String) {
        log(level: .info, message: message, component: component)
    }

    func warning(_ message: String, component: String) {
        log(level: .warning, message: message, component: component)
    }

    func error(_ message: String, component: String) {
        log(level: .error, message: message, component: component)
    }

    private func log(level: LogLevel, message: String, component: String) {
        let timestamp = dateFormatter.string(from: Date())
        let formattedMessage = "[\(timestamp)] [\(level.rawValue.uppercased())] [\(component)] \(message)"

        // Log to system (os_log)
        os_log("%{public}@", log: osLog, type: level.osLogType, formattedMessage)

        // Log to file
        logQueue.async { [weak self] in
            guard let self = self,
                  let data = (formattedMessage + "\n").data(using: .utf8) else {
                return
            }

            self.fileHandle?.seekToEndOfFile()
            self.fileHandle?.write(data)
        }

        #if DEBUG
        print(formattedMessage)
        #endif
    }
}

enum LogLevel: String {
    case debug
    case info
    case warning
    case error

    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        }
    }
}

import Foundation

/// Prints to stdout. Swap for a real analytics/crash-reporting SDK's logger when you add
/// one — everything else stays the same since callers only depend on `EventLogger`.
struct ConsoleEventLogger: EventLogger {
    func debug(_ message: String, category: LogCategory) {
        log(level: "DEBUG", message: message, category: category)
    }

    func info(_ message: String, category: LogCategory) {
        log(level: "INFO", message: message, category: category)
    }

    func warn(_ message: String, category: LogCategory) {
        log(level: "WARN", message: message, category: category)
    }

    func error(_ message: String, category: LogCategory) {
        log(level: "ERROR", message: message, category: category)
    }

    private func log(level: String, message: String, category: LogCategory) {
        print("[\(level)][\(category.rawValue)] \(message)")
    }
}

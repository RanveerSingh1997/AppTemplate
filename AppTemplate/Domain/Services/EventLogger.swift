import Foundation

enum LogCategory: String {
    case general, network, ui, persistence, security
}

/// Leveled logging seam. Not consumed anywhere yet — swap `ConsoleEventLogger` for a real
/// analytics/crash-reporting SDK's logger when you add one; use `NoOpEventLogger` in tests.
protocol EventLogger: Sendable {
    func debug(_ message: String, category: LogCategory)
    func info(_ message: String, category: LogCategory)
    func warn(_ message: String, category: LogCategory)
    func error(_ message: String, category: LogCategory)
}

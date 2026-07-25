import Foundation

/// Discards everything — use in tests so assertions aren't buried in log noise.
struct NoOpEventLogger: EventLogger {
    func debug(_ message: String, category: LogCategory) {}
    func info(_ message: String, category: LogCategory) {}
    func warn(_ message: String, category: LogCategory) {}
    func error(_ message: String, category: LogCategory) {}
}

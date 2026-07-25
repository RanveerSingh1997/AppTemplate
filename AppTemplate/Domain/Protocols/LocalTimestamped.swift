import Foundation

/// Adopt on every `@Model` that needs local audit timestamps (cache staleness checks,
/// "last synced" displays, cleanup-old-records jobs).
protocol LocalTimestamped: AnyObject {
    var localInsertedAt: Date { get set }
    var localUpdatedAt: Date { get set }
}

extension LocalTimestamped {
    /// Call on insert paths — sets both stamps to `now`.
    func markInserted(_ date: Date = .now) {
        localInsertedAt = date
        localUpdatedAt = date
    }

    /// Call whenever the entity's data is refreshed from a new source.
    func markUpdated(_ date: Date = .now) {
        localUpdatedAt = date
    }
}

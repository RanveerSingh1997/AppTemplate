import Foundation
import SwiftData

/// Local cache for offline-first reads. Kept separate from `ItemDTO` (network shape) and
/// `Item` (domain shape) so the persistence schema can evolve independently of either.
@Model
final class CachedItem {
    @Attribute(.unique) var id: String
    var title: String
    var detail: String
    var priorityID: String?
    var localInsertedAt: Date
    var localUpdatedAt: Date

    init(id: String, title: String, detail: String, priorityID: String? = nil) {
        self.id = id
        self.title = title
        self.detail = detail
        self.priorityID = priorityID
        localInsertedAt = .now
        localUpdatedAt = .now
    }
}

extension CachedItem: LocalTimestamped {}

/// Its existing `id: String` already satisfies this — declared explicitly so
/// `SwiftDataStore<CachedItem>.first(withID:)` (a generic, `Identifiable`-constrained
/// query) is available.
extension CachedItem: Identifiable {}

extension CachedItem {
    var asDomain: Item { Item(id: id, title: title, detail: detail, priorityID: priorityID) }
}

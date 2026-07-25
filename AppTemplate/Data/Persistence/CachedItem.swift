import Foundation
import SwiftData

/// Local cache for offline-first reads. Kept separate from `ItemDTO` (network shape) and
/// `Item` (domain shape) so the persistence schema can evolve independently of either.
@Model
final class CachedItem {
    @Attribute(.unique) var id: String
    var title: String
    var detail: String
    var localInsertedAt: Date
    var localUpdatedAt: Date

    init(id: String, title: String, detail: String) {
        self.id = id
        self.title = title
        self.detail = detail
        localInsertedAt = .now
        localUpdatedAt = .now
    }
}

extension CachedItem: LocalTimestamped {}

extension CachedItem {
    var asDomain: Item { Item(id: id, title: title, detail: detail) }
}

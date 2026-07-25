import Foundation

/// The domain-facing model. Presentation and Domain code only ever see this shape —
/// never `ItemDTO` (network) or `CachedItem` (persistence) directly. Rename/replace with
/// your own entity; keep the same rule: only Data-layer mappers know the other two exist.
struct Item: Identifiable, Hashable, Sendable {
    let id: String
    var title: String
    var detail: String
}

import Foundation

/// The network's shape for an item — deliberately named differently from the domain
/// model (`name`/`description` vs. `title`/`detail`) to make the point that API and
/// domain vocabularies drift, and `ItemMapper` is what isolates that drift.
struct ItemDTO: Codable, Sendable {
    let id: String
    var name: String
    var description: String
    var priorityID: String?
}

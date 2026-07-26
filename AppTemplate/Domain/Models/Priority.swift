import Foundation

/// Reference/lookup data for populating a picker — not something a user creates, edits,
/// or deletes through this app. See `PriorityRepository`'s doc comment for how this is
/// meant to be fetched, and the README's "consuming multiple fetched data sources" section
/// for when this graduates from "fetch fresh each time" to a shared, synced cache.
struct Priority: Identifiable, Hashable, Sendable {
    let id: String
    var name: String
}

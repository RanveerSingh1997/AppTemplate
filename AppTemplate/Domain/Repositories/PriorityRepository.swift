import Foundation

/// Deliberately simpler than `ItemRepository`: no persistence/cache-fallback, because
/// priorities are cheap lookup data it's fine to re-fetch each time a form needs them.
/// Not every repository needs the full DTO -> Entity -> Domain machinery — this is the
/// shape to copy for reference data, `ItemRepository`'s is the shape for user-owned data.
protocol PriorityRepository {
    func fetchPriorities() async throws -> [Priority]
}

import Foundation
import SwiftData

enum PersistenceFactory {
    static let schema = Schema([CachedItem.self])

    /// Falls back to an in-memory store if the on-disk store can't be opened (e.g. corrupted
    /// after an interrupted migration), so a bad local database never crashes the app at
    /// launch. `fatalError` only remains for the case where even the in-memory store fails,
    /// which is a framework-level failure, not a config mistake.
    static func makeContainer() -> (container: ModelContainer, startupError: AppError?) {
        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return (try ModelContainer(for: schema, configurations: [config]), nil)
        } catch {
            let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            guard let fallback = try? ModelContainer(for: schema, configurations: [inMemoryConfig]) else {
                fatalError("Could not create in-memory model container: \(error)")
            }
            return (fallback, .persistence(.saveFailed))
        }
    }
}

import Foundation
import SwiftData

/// Maps between a network DTO and a persisted SwiftData entity. Keeping this as its own
/// type (rather than ad hoc `asX`/`asY` computed properties) is what lets the DTO's shape
/// change independently of the persistence schema — a renamed/reshaped API field only
/// requires editing the mapper, never every call site. Lives in `Data/`, not `Domain/`,
/// despite the generic-looking name — it knows about `SwiftDataStore`/`PersistentModel`,
/// so it's exactly the kind of persistence-framework-aware type Domain must never import.
protocol EntityMapper {
    associatedtype DTO: Codable & Sendable
    associatedtype Entity: PersistentModel & LocalTimestamped

    /// Creates a new entity from a DTO and inserts it via `store`.
    @MainActor
    func toEntity(dto: DTO, store: SwiftDataStore<Entity>) -> Result<Entity, AppError>

    /// Converts a persisted Entity back into its network-facing DTO shape.
    func toDTO(entity: Entity) -> Result<DTO, AppError>

    /// Updates an existing Entity in place from a fresh DTO (e.g. after a re-fetch),
    /// bumping its `localUpdatedAt` stamp. No `store` parameter — SwiftData tracks
    /// already-inserted entities' mutations on its own; nothing needs re-inserting.
    func updateEntity(_ entity: Entity, with dto: DTO) -> Result<Entity, AppError>
}

extension EntityMapper {
    /// Bulk conversion that fails fast on the first bad DTO rather than partially caching.
    @MainActor
    func toEntities(dtos: [DTO], store: SwiftDataStore<Entity>) -> Result<[Entity], AppError> {
        var entities: [Entity] = []
        for dto in dtos {
            switch toEntity(dto: dto, store: store) {
            case .success(let entity):
                entities.append(entity)
            case .failure(let error):
                return .failure(error)
            }
        }
        return .success(entities)
    }
}

import Foundation
import SwiftData

/// Maps between a network DTO and a persisted SwiftData entity. Keeping this as its own
/// type (rather than ad hoc `asX`/`asY` computed properties) is what lets the DTO's shape
/// change independently of the persistence schema — a renamed/reshaped API field only
/// requires editing the mapper, never every call site.
protocol EntityMapper {
    associatedtype DTO: Codable & Sendable
    associatedtype Entity: PersistentModel & LocalTimestamped

    /// Creates a new persisted Entity from a DTO.
    func toEntity(dto: DTO, context: ModelContext) -> Result<Entity, AppError>

    /// Converts a persisted Entity back into its network-facing DTO shape.
    func toDTO(entity: Entity) -> Result<DTO, AppError>

    /// Updates an existing Entity in place from a fresh DTO (e.g. after a re-fetch),
    /// bumping its `localUpdatedAt` stamp.
    func updateEntity(_ entity: Entity, with dto: DTO, context: ModelContext) -> Result<Entity, AppError>
}

extension EntityMapper {
    /// Bulk conversion that fails fast on the first bad DTO rather than partially caching.
    func toEntities(dtos: [DTO], context: ModelContext) -> Result<[Entity], AppError> {
        var entities: [Entity] = []
        for dto in dtos {
            switch toEntity(dto: dto, context: context) {
            case .success(let entity):
                entities.append(entity)
            case .failure(let error):
                return .failure(error)
            }
        }
        return .success(entities)
    }
}

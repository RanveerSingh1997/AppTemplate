import Foundation
import SwiftData

/// The one place that knows both `ItemDTO` (network) and `CachedItem` (persistence).
/// A renamed/reshaped API field only requires editing this file.
struct ItemMapper: EntityMapper {
    func toEntity(dto: ItemDTO, context: ModelContext) -> Result<CachedItem, AppError> {
        let entity = CachedItem(id: dto.id, title: dto.name, detail: dto.description, priorityID: dto.priorityID)
        entity.markInserted()
        context.insert(entity)
        return .success(entity)
    }

    func toDTO(entity: CachedItem) -> Result<ItemDTO, AppError> {
        .success(ItemDTO(id: entity.id, name: entity.title, description: entity.detail, priorityID: entity.priorityID))
    }

    func updateEntity(_ entity: CachedItem, with dto: ItemDTO, context: ModelContext) -> Result<CachedItem, AppError> {
        entity.title = dto.name
        entity.detail = dto.description
        entity.priorityID = dto.priorityID
        entity.markUpdated()
        return .success(entity)
    }
}

extension ItemDTO {
    var asDomain: Item { Item(id: id, title: name, detail: description, priorityID: priorityID) }
}

extension Item {
    var asDTO: ItemDTO { ItemDTO(id: id, name: title, description: detail, priorityID: priorityID) }
}

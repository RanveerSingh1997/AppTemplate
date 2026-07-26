import Foundation

struct PriorityDTO: Codable, Sendable {
    let id: String
    var name: String
}

extension PriorityDTO {
    var asDomain: Priority { Priority(id: id, name: name) }
}

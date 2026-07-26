import Foundation

/// No persistence layer, unlike `ItemRepositoryImpl` — see `PriorityRepository`'s doc
/// comment for why that's the right amount of machinery for reference data.
struct PriorityRepositoryImpl: PriorityRepository {
    let apiClient: APIClient

    func fetchPriorities() async throws -> [Priority] {
        let dtos: [PriorityDTO] = try await apiClient.send(APIRequest(endpoint: .fetchPriorities))
        return dtos.map(\.asDomain)
    }
}

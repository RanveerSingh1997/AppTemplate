import Foundation

final class MockPriorityRepositoryImpl: PriorityRepository {
    private let priorities: [Priority]

    init(priorities: [Priority] = MockPriorityRepositoryImpl.samplePriorities) {
        self.priorities = priorities
    }

    func fetchPriorities() async throws -> [Priority] {
        priorities
    }

    static let samplePriorities: [Priority] = [
        Priority(id: "low", name: "Low"),
        Priority(id: "medium", name: "Medium"),
        Priority(id: "high", name: "High"),
        Priority(id: "urgent", name: "Urgent")
    ]
}

import Foundation

final class MockPriorityRepositoryImpl: PriorityRepository {
    private let priorities: [Priority]
    /// Set in tests that need `fetchPriorities` to fail deterministically (e.g. simulating
    /// offline) — nil (never throws) for normal dev use.
    private let fetchError: Error?

    init(priorities: [Priority] = MockPriorityRepositoryImpl.samplePriorities, fetchError: Error? = nil) {
        self.priorities = priorities
        self.fetchError = fetchError
    }

    func fetchPriorities() async throws -> [Priority] {
        if let fetchError { throw fetchError }
        return priorities
    }

    static let samplePriorities: [Priority] = [
        Priority(id: "low", name: "Low"),
        Priority(id: "medium", name: "Medium"),
        Priority(id: "high", name: "High"),
        Priority(id: "urgent", name: "Urgent")
    ]
}

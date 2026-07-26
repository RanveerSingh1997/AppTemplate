@testable import AppTemplate
import Testing

struct MockPriorityRepositoryImplTests {
    @Test
    func fetchPrioritiesReturnsSampleData() async throws {
        let repository = MockPriorityRepositoryImpl()
        let priorities = try await repository.fetchPriorities()
        #expect(priorities.map(\.name) == ["Low", "Medium", "High", "Urgent"])
    }
}

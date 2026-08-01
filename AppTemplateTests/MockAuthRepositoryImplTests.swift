@testable import AppTemplate
import Testing

struct MockAuthRepositoryImplTests {
    @Test
    func loginSucceedsWithTheDemoCredential() async throws {
        let repository = MockAuthRepositoryImpl()
        let session = try await repository.login(
            email: MockAuthRepositoryImpl.demoEmail,
            password: MockAuthRepositoryImpl.demoPassword
        )
        #expect(session.email == MockAuthRepositoryImpl.demoEmail)
        #expect(!session.token.isEmpty)
    }

    @Test
    func loginFailsWithAnyOtherCredential() async throws {
        let repository = MockAuthRepositoryImpl()
        await #expect(throws: AppError.self) {
            try await repository.login(email: "wrong@example.com", password: "wrong")
        }
    }
}

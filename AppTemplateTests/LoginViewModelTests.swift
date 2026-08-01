@testable import AppTemplate
import Testing

@MainActor
struct LoginViewModelTests {
    private func makeViewModel(authRepository: AuthRepository = MockAuthRepositoryImpl()) -> LoginViewModel {
        LoginViewModel(authRepository: authRepository, demoCredentialsHint: nil)
    }

    @Test
    func canSubmitIsFalseUntilBothFieldsAreFilled() {
        let viewModel = makeViewModel()
        #expect(!viewModel.canSubmit)

        viewModel.email = "demo@example.com"
        #expect(!viewModel.canSubmit)

        viewModel.password = "password"
        #expect(viewModel.canSubmit)
    }

    @Test
    func loginSucceedsWithTheDemoCredentialAndReturnsAToken() async {
        let viewModel = makeViewModel()
        viewModel.email = MockAuthRepositoryImpl.demoEmail
        viewModel.password = MockAuthRepositoryImpl.demoPassword

        let token = await viewModel.login()

        #expect(token != nil)
        #expect(viewModel.loginError == nil)
    }

    @Test
    func loginFailsWithTheWrongPasswordAndSetsLoginError() async {
        let viewModel = makeViewModel()
        viewModel.email = MockAuthRepositoryImpl.demoEmail
        viewModel.password = "wrong"

        let token = await viewModel.login()

        #expect(token == nil)
        #expect(viewModel.loginError != nil)
    }
}

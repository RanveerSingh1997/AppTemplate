import SwiftUI

struct LoginView: View {
    @State private var viewModel: LoginViewModel
    let authSessionStore: AuthSessionStore

    init(viewModel: LoginViewModel, authSessionStore: AuthSessionStore) {
        _viewModel = State(initialValue: viewModel)
        self.authSessionStore = authSessionStore
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.large) {
                Image(systemName: Icons.appIcon)
                    .font(Typography.heroIcon)
                    .foregroundStyle(Colors.accent)

                VStack(spacing: Spacing.medium) {
                    ValidatedTextField(title: AppStrings.email, text: $viewModel.email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    ValidatedTextField(
                        title: AppStrings.password,
                        text: $viewModel.password,
                        isSecure: true,
                        errorMessage: viewModel.loginError?.errorDescription
                    )
                }

                if viewModel.isLoggingIn {
                    ProgressView()
                } else {
                    Button(AppStrings.logIn, action: submit)
                        .buttonStyle(.primary)
                        .disabled(!viewModel.canSubmit)
                }

                if let hint = viewModel.demoCredentialsHint {
                    Text(hint)
                        .font(Typography.caption)
                        .foregroundStyle(Colors.secondaryText)
                }
            }
            .padding(.horizontal, Spacing.large)
            .navigationTitle(AppStrings.logIn)
        }
    }

    private func submit() {
        Task {
            if let token = await viewModel.login() {
                authSessionStore.signIn(token: token)
            }
        }
    }
}

#Preview {
    LoginView(
        viewModel: LoginViewModel(
            authRepository: MockAuthRepositoryImpl(),
            demoCredentialsHint: "Demo: demo@example.com / password"
        ),
        authSessionStore: AuthSessionStore(secureStorageService: InMemorySecureStorageService())
    )
}

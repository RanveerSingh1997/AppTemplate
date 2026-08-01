import SwiftUI

struct AppContainerView: View {
    let dependencies: AppDependencies
    @State private var isSplashComplete = false
    @State private var startupError: AppError?

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _startupError = State(initialValue: dependencies.startupError)
    }

    var body: some View {
        Group {
            if isSplashComplete {
                MainTabView(dependencies: dependencies)
            } else {
                SplashView(viewModel: dependencies.makeSplashViewModel()) {
                    isSplashComplete = true
                }
            }
        }
        .alert(
            AppStrings.couldntOpenLocalStorage,
            isPresented: Binding(
                get: { startupError != nil },
                set: { if !$0 { startupError = nil } }
            )
        ) {
            Button(AppStrings.ok, role: .cancel) { startupError = nil }
        } message: {
            Text(startupError?.localizedDescription ?? AppStrings.usingTemporaryInMemoryStore)
        }
        .alertCenterOverlay(dependencies.alertCenter)
    }
}

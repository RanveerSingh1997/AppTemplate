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
            "Couldn't Open Local Storage",
            isPresented: Binding(
                get: { startupError != nil },
                set: { if !$0 { startupError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { startupError = nil }
        } message: {
            Text(startupError?.localizedDescription ?? "Using a temporary in-memory store for this session.")
        }
    }
}

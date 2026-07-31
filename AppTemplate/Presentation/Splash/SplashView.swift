import SwiftUI

struct SplashView: View {
    @State private var viewModel: SplashViewModel
    let onFinished: () -> Void

    init(viewModel: SplashViewModel, onFinished: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onFinished = onFinished
    }

    var body: some View {
        VStack(spacing: Spacing.large) {
            Image(systemName: "app.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("AppTemplate")
                .font(.title.bold())
        }
        .task {
            await viewModel.prepare()
            if viewModel.isReady { onFinished() }
        }
    }
}

#Preview {
    SplashView(viewModel: SplashViewModel()) {}
}

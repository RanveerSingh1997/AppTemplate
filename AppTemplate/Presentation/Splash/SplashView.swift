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
            Image(systemName: Icons.appIcon)
                .font(Typography.heroIcon)
                .foregroundStyle(Colors.accent)
            Text(AppStrings.appName)
                .font(Typography.heading)
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

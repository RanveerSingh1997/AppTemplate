import SwiftUI

struct SettingsView: View {
    let viewModel: SettingsViewModel
    @Bindable var coordinator: NavigationCoordinator

    var body: some View {
        NavigationStack(path: $coordinator.settingsPath) {
            Form {
                Section(AppStrings.about) {
                    LabeledContent(AppStrings.version, value: viewModel.appVersion)
                    LabeledContent(AppStrings.environment, value: viewModel.environment.rawValue)
                }
                Button(AppStrings.aboutThisTemplate) {
                    coordinator.push(.about)
                }
            }
            .navigationTitle(AppStrings.settings)
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .about:
                    AboutView()
                }
            }
        }
    }
}

private struct AboutView: View {
    var body: some View {
        VStack(spacing: Spacing.medium) {
            Image(systemName: "app.badge.checkmark")
                .font(Typography.sectionIcon)
                .foregroundStyle(Colors.accent)
            Text(AppStrings.appName)
                .font(Typography.subheading)
            Text(AppStrings.aboutDescription)
                .multilineTextAlignment(.center)
                .foregroundStyle(Colors.secondaryText)
                .padding(.horizontal)
        }
        .navigationTitle(AppStrings.about)
    }
}

#Preview {
    SettingsView(viewModel: SettingsViewModel(environment: .dev), coordinator: NavigationCoordinator())
}

#Preview("About") {
    NavigationStack { AboutView() }
}

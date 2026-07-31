import SwiftUI

struct SettingsView: View {
    let viewModel: SettingsViewModel
    @Bindable var coordinator: NavigationCoordinator

    var body: some View {
        NavigationStack(path: $coordinator.settingsPath) {
            Form {
                Section("About") {
                    LabeledContent("Version", value: viewModel.appVersion)
                    LabeledContent("Environment", value: viewModel.environment.rawValue)
                }
                Button("About This Template") {
                    coordinator.push(.about)
                }
            }
            .navigationTitle("Settings")
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
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("AppTemplate")
                .font(.title2.bold())
            Text("A starting point following Clean Architecture: Core, Domain, Data, Presentation. See README.md.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .navigationTitle("About")
    }
}

#Preview {
    SettingsView(viewModel: SettingsViewModel(environment: .dev), coordinator: NavigationCoordinator())
}

#Preview("About") {
    NavigationStack { AboutView() }
}

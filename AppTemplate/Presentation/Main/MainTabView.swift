import SwiftUI

struct MainTabView: View {
    let dependencies: AppDependencies

    var body: some View {
        TabView {
            HomeSplitView(
                viewModel: dependencies.makeHomeViewModel(),
                coordinator: dependencies.coordinator,
                makeDetailViewModel: dependencies.makeItemDetailViewModel,
                makeFormViewModel: dependencies.makeAddEditItemViewModel
            )
            .tabItem { Label(AppStrings.home, systemImage: Icons.homeTab) }

            SettingsView(
                viewModel: dependencies.makeSettingsViewModel(),
                coordinator: dependencies.coordinator,
                authSessionStore: dependencies.authSessionStore
            )
            .tabItem { Label(AppStrings.settings, systemImage: Icons.settingsTab) }
        }
    }
}

#Preview {
    // AppEnvironment.current falls back to .dev when the ENVName Info.plist key isn't
    // set (true in an Xcode Preview), so this wires the in-memory mock repositories.
    MainTabView(dependencies: AppDependencies())
}

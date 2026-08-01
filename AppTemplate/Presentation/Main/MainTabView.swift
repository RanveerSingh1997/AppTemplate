import SwiftUI

struct MainTabView: View {
    let dependencies: AppDependencies
    @Bindable private var coordinator: NavigationCoordinator

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        self.coordinator = dependencies.coordinator
    }

    var body: some View {
        // `selection:` (not the tag-less initializer) so a deep link — or anything else
        // that sets `coordinator.selectedTab` — can switch tabs programmatically; see
        // `NavigationCoordinator.handle(url:)`.
        TabView(selection: $coordinator.selectedTab) {
            HomeSplitView(
                viewModel: dependencies.makeHomeViewModel(),
                coordinator: dependencies.coordinator,
                makeDetailViewModel: dependencies.makeItemDetailViewModel,
                makeFormViewModel: dependencies.makeAddEditItemViewModel
            )
            .tabItem { Label(AppStrings.home, systemImage: Icons.homeTab) }
            .tag(AppTab.home)

            SettingsView(
                viewModel: dependencies.makeSettingsViewModel(),
                coordinator: dependencies.coordinator,
                authSessionStore: dependencies.authSessionStore
            )
            .tabItem { Label(AppStrings.settings, systemImage: Icons.settingsTab) }
            .tag(AppTab.settings)
        }
    }
}

#Preview {
    // AppEnvironment.current falls back to .dev when the ENVName Info.plist key isn't
    // set (true in an Xcode Preview), so this wires the in-memory mock repositories.
    MainTabView(dependencies: AppDependencies())
}

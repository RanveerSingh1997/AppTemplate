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
            .tabItem { Label("Home", systemImage: "list.bullet") }

            SettingsView(
                viewModel: dependencies.makeSettingsViewModel(),
                coordinator: dependencies.coordinator
            )
            .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

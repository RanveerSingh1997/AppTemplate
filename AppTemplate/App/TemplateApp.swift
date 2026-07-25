import SwiftData
import SwiftUI

@main
struct TemplateApp: App {
    @State private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            AppContainerView(dependencies: dependencies)
                .modelContainer(dependencies.modelContainer)
        }
    }
}

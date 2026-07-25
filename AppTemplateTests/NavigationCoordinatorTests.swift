@testable import AppTemplate
import Testing

@MainActor
struct NavigationCoordinatorTests {
    @Test
    func selectingAnItemUpdatesSelection() {
        let coordinator = NavigationCoordinator()
        coordinator.selectItem("42")
        #expect(coordinator.selectedItemID == "42")
    }

    @Test
    func pushingARouteAddsToSettingsPath() {
        let coordinator = NavigationCoordinator()
        #expect(coordinator.settingsPath.isEmpty)
        coordinator.push(.about)
        #expect(coordinator.settingsPath.count == 1)
    }
}

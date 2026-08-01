@testable import AppTemplate
import Foundation
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

    @Test
    func handlingAnItemsLinkSelectsTheHomeTabAndTheItem() {
        let coordinator = NavigationCoordinator()
        coordinator.selectedTab = .settings

        let handled = coordinator.handle(url: URL(string: "apptemplate://items/42")!)

        #expect(handled)
        #expect(coordinator.selectedTab == .home)
        #expect(coordinator.selectedItemID == "42")
    }

    @Test
    func handlingAnItemsLinkWithNoIDIsNotHandled() {
        let coordinator = NavigationCoordinator()
        #expect(!coordinator.handle(url: URL(string: "apptemplate://items")!))
    }

    @Test
    func handlingASettingsLinkSelectsTheSettingsTab() {
        let coordinator = NavigationCoordinator()

        let handled = coordinator.handle(url: URL(string: "apptemplate://settings")!)

        #expect(handled)
        #expect(coordinator.selectedTab == .settings)
        #expect(coordinator.settingsPath.isEmpty)
    }

    @Test
    func handlingASettingsAboutLinkPushesAbout() {
        let coordinator = NavigationCoordinator()

        let handled = coordinator.handle(url: URL(string: "apptemplate://settings/about")!)

        #expect(handled)
        #expect(coordinator.selectedTab == .settings)
        #expect(coordinator.settingsPath.count == 1)
    }

    @Test
    func handlingASettingsLinkResetsAnyExistingPushedPath() {
        let coordinator = NavigationCoordinator()
        coordinator.push(.about)

        #expect(coordinator.handle(url: URL(string: "apptemplate://settings")!))
        #expect(coordinator.settingsPath.isEmpty)
    }

    @Test
    func handlingAnUnrecognizedHostIsNotHandled() {
        let coordinator = NavigationCoordinator()
        #expect(!coordinator.handle(url: URL(string: "apptemplate://unknown")!))
    }
}

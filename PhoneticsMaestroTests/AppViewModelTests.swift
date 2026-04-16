import SwiftUI
import XCTest
@testable import PhoneticsCore

@MainActor
final class AppViewModelTests: XCTestCase {
    func testAppScreenCasesExcludeWelcome() {
        XCTAssertEqual(AppScreen.allCases, [.training, .history, .settings])
    }

    func testToggleSidebarUpdatesCollapsedState() {
        let viewModel = AppViewModel()

        XCTAssertEqual(viewModel.splitViewVisibility, .all)
        XCTAssertFalse(viewModel.isSidebarCollapsed)

        viewModel.toggleSidebar()
        XCTAssertEqual(viewModel.splitViewVisibility, .detailOnly)
        XCTAssertTrue(viewModel.isSidebarCollapsed)

        viewModel.toggleSidebar()
        XCTAssertEqual(viewModel.splitViewVisibility, .all)
        XCTAssertFalse(viewModel.isSidebarCollapsed)
    }

    func testInitializedAppDefaultsToTrainingWhenOnboardingIsDismissed() async {
        let settingsService = MockOnboardingSettingsDataService(
            settings: AppSettings(hasDismissedOnboarding: true)
        )
        let viewModel = AppViewModel(settingsService: settingsService)

        await viewModel.initialize()

        XCTAssertEqual(viewModel.selectedScreen, .training)
        XCTAssertFalse(viewModel.shouldShowOnboarding)
    }

    func testInitializedAppShowsOnboardingUntilDismissed() async {
        let settingsService = MockOnboardingSettingsDataService(settings: AppSettings())
        let viewModel = AppViewModel(settingsService: settingsService)

        await viewModel.initialize()

        XCTAssertEqual(viewModel.selectedScreen, .training)
        XCTAssertTrue(viewModel.shouldShowOnboarding)

        await viewModel.dismissOnboarding()

        let updatedSettings = await settingsService.latestUpdatedSettings()
        XCTAssertFalse(viewModel.shouldShowOnboarding)
        XCTAssertEqual(updatedSettings?.hasDismissedOnboarding, true)
        XCTAssertEqual(viewModel.selectedScreen, .training)
    }
}

actor MockOnboardingSettingsDataService: SettingsDataServing {
    private var storedSettings: AppSettings
    private var lastUpdatedSettings: AppSettings?

    init(settings: AppSettings) {
        self.storedSettings = settings
    }

    func fetchSettings() async throws -> AppSettings {
        storedSettings
    }

    func updateSettings(_ settings: AppSettings) async throws {
        storedSettings = settings
        lastUpdatedSettings = settings
    }

    func latestUpdatedSettings() -> AppSettings? {
        lastUpdatedSettings
    }
}

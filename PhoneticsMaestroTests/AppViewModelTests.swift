import SwiftUI
import XCTest
@testable import PhoneticsCore

@MainActor
final class AppViewModelTests: XCTestCase {
    func testAppScreenCasesExcludeWelcome() {
        XCTAssertEqual(AppScreen.allCases, [.training, .history, .settings])
        XCTAssertEqual(AppScreen.training.title, "Begin")
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

    func testInitializeUsesInjectedAppInitializer() async {
        let initializer = MockAppInitializer()
        let settingsService = MockOnboardingSettingsDataService(
            settings: AppSettings(hasDismissedOnboarding: true)
        )
        let viewModel = AppViewModel(
            trainingCardViewModel: TrainingCardViewModel(
                dataService: MockTrainingDataService(),
                audioService: MockTrainingAudioService(randomTestIndex: 0)
            ),
            appInitializer: initializer,
            settingsService: settingsService
        )

        await viewModel.initialize()

        let callCount = await initializer.callCount()
        XCTAssertEqual(callCount, 1)
    }
}

actor MockAppInitializer: AppInitializing {
    private var initializeCount = 0

    func initialize() async throws {
        initializeCount += 1
    }

    func callCount() -> Int {
        initializeCount
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

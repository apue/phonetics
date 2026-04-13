import XCTest
@testable import PhoneticsMaestro

@MainActor
final class SettingsViewModelTests: XCTestCase {
    func testLoadSettingsUsesPersistedValues() async {
        let dataService = MockSettingsDataService(
            settings: AppSettings(
                preferredVoiceName: "Daniel",
                preferredMicrophoneName: "USB Mic",
                ababIntervalMilliseconds: 400
            )
        )
        let optionsProvider = MockSettingsOptionsProvider()
        let viewModel = SettingsViewModel(
            dataService: dataService,
            optionsProvider: optionsProvider
        )

        await viewModel.loadSettings()

        XCTAssertEqual(viewModel.preferredVoiceName, "Daniel")
        XCTAssertEqual(viewModel.preferredMicrophoneName, "USB Mic")
        XCTAssertEqual(viewModel.ababIntervalMilliseconds, 400)
        XCTAssertEqual(viewModel.availableVoiceNames, ["System Default", "Daniel"])
        XCTAssertEqual(viewModel.availableMicrophoneNames, ["System Default", "USB Mic"])
    }

    func testSaveSettingsFailureRestoresSavingState() async {
        let dataService = MockSettingsDataService(updateError: DataServiceError.database("save failed"))
        let viewModel = SettingsViewModel(
            dataService: dataService,
            optionsProvider: MockSettingsOptionsProvider()
        )

        await viewModel.saveSettings()

        XCTAssertFalse(viewModel.isSaving)
        XCTAssertEqual(viewModel.errorMessage, "Database error: save failed")
    }
}

actor MockSettingsDataService: SettingsDataServing {
    private var settings: AppSettings
    private let updateError: Error?

    init(settings: AppSettings = AppSettings(), updateError: Error? = nil) {
        self.settings = settings
        self.updateError = updateError
    }

    func fetchSettings() async throws -> AppSettings {
        settings
    }

    func updateSettings(_ settings: AppSettings) async throws {
        if let updateError {
            throw updateError
        }

        self.settings = settings
    }
}

struct MockSettingsOptionsProvider: SettingsOptionsProviding {
    func availableVoiceNames() -> [String] {
        ["System Default"]
    }

    func availableMicrophoneNames() -> [String] {
        ["System Default"]
    }
}

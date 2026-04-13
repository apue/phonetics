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
}

actor MockSettingsDataService: SettingsDataServing {
    private var settings: AppSettings

    init(settings: AppSettings = AppSettings()) {
        self.settings = settings
    }

    func fetchSettings() async throws -> AppSettings {
        settings
    }

    func updateSettings(_ settings: AppSettings) async throws {
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

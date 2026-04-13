import Observation

@MainActor
@Observable
final class SettingsViewModel {
    var availableVoiceNames: [String] = ["System Default"]
    var availableMicrophoneNames: [String] = ["System Default"]
    var preferredVoiceName = "System Default"
    var preferredMicrophoneName = "System Default"
    var ababIntervalMilliseconds = 300
    var isLoading = false
    var isSaving = false
    var errorMessage: String?

    private let dataService: any SettingsDataServing
    private let optionsProvider: any SettingsOptionsProviding

    init(
        dataService: any SettingsDataServing = DataService.shared,
        optionsProvider: any SettingsOptionsProviding = SystemSettingsOptionsProvider()
    ) {
        self.dataService = dataService
        self.optionsProvider = optionsProvider
    }

    func loadSettings() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let settings = try await dataService.fetchSettings()
            availableVoiceNames = mergedOptions(
                persistedValue: settings.preferredVoiceName,
                options: optionsProvider.availableVoiceNames()
            )
            availableMicrophoneNames = mergedOptions(
                persistedValue: settings.preferredMicrophoneName,
                options: optionsProvider.availableMicrophoneNames()
            )
            preferredVoiceName = settings.preferredVoiceName
            preferredMicrophoneName = settings.preferredMicrophoneName
            ababIntervalMilliseconds = settings.ababIntervalMilliseconds
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveSettings() async {
        guard !isSaving else {
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            try await dataService.updateSettings(
                AppSettings(
                    preferredVoiceName: preferredVoiceName,
                    preferredMicrophoneName: preferredMicrophoneName,
                    ababIntervalMilliseconds: ababIntervalMilliseconds
                )
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func mergedOptions(persistedValue: String, options: [String]) -> [String] {
        let ordered = ["System Default"] + options + [persistedValue]
        return ordered.reduce(into: [String]()) { result, option in
            if !result.contains(option) {
                result.append(option)
            }
        }
    }
}

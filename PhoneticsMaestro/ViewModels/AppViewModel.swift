import Observation
import SwiftUI

@MainActor
@Observable
public final class AppViewModel {
    var selectedScreen: AppScreen = .training
    var splitViewVisibility: NavigationSplitViewVisibility = .all
    var isInitializing = false
    var isInitialized = false
    var shouldShowOnboarding = false
    var errorMessage: String?

    var isSidebarCollapsed: Bool {
        splitViewVisibility == .detailOnly
    }

    let trainingCardViewModel: TrainingCardViewModel
    private let settingsService: any SettingsDataServing

    public init() {
        trainingCardViewModel = TrainingCardViewModel()
        settingsService = DataService.shared
    }

    init(
        trainingCardViewModel: TrainingCardViewModel = TrainingCardViewModel(),
        settingsService: any SettingsDataServing = DataService.shared
    ) {
        self.trainingCardViewModel = trainingCardViewModel
        self.settingsService = settingsService
    }

    public func initialize() async {
        guard !isInitializing, !isInitialized else {
            return
        }

        isInitializing = true
        defer { isInitializing = false }

        do {
            try await DataService.shared.initialize()
            let settings = try await settingsService.fetchSettings()
            shouldShowOnboarding = !settings.hasDismissedOnboarding
            selectedScreen = .training
            isInitialized = true
            await trainingCardViewModel.loadInitialPair()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissOnboarding() async {
        guard shouldShowOnboarding else {
            return
        }

        do {
            var settings = try await settingsService.fetchSettings()
            settings.hasDismissedOnboarding = true
            try await settingsService.updateSettings(settings)
            shouldShowOnboarding = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleSidebar() {
        splitViewVisibility = isSidebarCollapsed ? .all : .detailOnly
    }
}

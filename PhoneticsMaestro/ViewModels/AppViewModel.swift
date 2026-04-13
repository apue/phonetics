import Observation
import SwiftUI

@MainActor
@Observable
final class AppViewModel {
    var selectedScreen: AppScreen = .welcome
    var splitViewVisibility: NavigationSplitViewVisibility = .all
    var isInitializing = false
    var isInitialized = false
    var errorMessage: String?

    var isSidebarCollapsed: Bool {
        splitViewVisibility == .detailOnly
    }

    let trainingCardViewModel: TrainingCardViewModel

    init(trainingCardViewModel: TrainingCardViewModel = TrainingCardViewModel()) {
        self.trainingCardViewModel = trainingCardViewModel
    }

    func initialize() async {
        guard !isInitializing, !isInitialized else {
            return
        }

        isInitializing = true
        defer { isInitializing = false }

        do {
            try await DataService.shared.initialize()
            isInitialized = true
            await trainingCardViewModel.loadInitialPair()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func showTraining() {
        selectedScreen = .training

        Task {
            await trainingCardViewModel.loadInitialPairIfNeeded()
        }
    }

    func toggleSidebar() {
        splitViewVisibility = isSidebarCollapsed ? .all : .detailOnly
    }
}

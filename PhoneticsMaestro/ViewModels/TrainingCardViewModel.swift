import Observation

@MainActor
@Observable
final class TrainingCardViewModel {
    var currentPair: PhonePair?
    var isLoading = false
    var errorMessage: String?

    private let dataService: DataService

    init(dataService: DataService = .shared) {
        self.dataService = dataService
    }

    func loadInitialPair() async {
        await loadPair(afterID: nil, forceReload: true)
    }

    func loadInitialPairIfNeeded() async {
        guard currentPair == nil else {
            return
        }

        await loadPair(afterID: nil, forceReload: false)
    }

    func loadNextPair() async {
        await loadPair(afterID: currentPair?.id, forceReload: false)
    }

    private func loadPair(afterID: Int64?, forceReload: Bool) async {
        guard !isLoading else {
            return
        }

        if !forceReload, currentPair == nil {
            errorMessage = nil
        }

        isLoading = true
        defer { isLoading = false }

        do {
            currentPair = try await dataService.fetchNextPair(afterID: afterID)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

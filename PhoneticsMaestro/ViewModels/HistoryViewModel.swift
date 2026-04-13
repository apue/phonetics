import Observation

@MainActor
@Observable
final class HistoryViewModel {
    var sessions: [HistorySessionSummary] = []
    var isLoading = false
    var errorMessage: String?

    private let dataService: any HistoryDataServing

    init(dataService: any HistoryDataServing = DataService.shared) {
        self.dataService = dataService
    }

    func loadHistory() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            sessions = try await dataService.fetchHistorySessionSummaries()
                .sorted { $0.sessionDate > $1.sessionDate }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

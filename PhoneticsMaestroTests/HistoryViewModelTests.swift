import XCTest
@testable import PhoneticsMaestro

@MainActor
final class HistoryViewModelTests: XCTestCase {
    func testLoadHistoryShowsMostRecentSessionsFirst() async {
        let dataService = MockHistoryDataService(
            summaries: [
                HistorySessionSummary(
                    sessionDate: "2026-04-12",
                    totalListens: 5,
                    totalCorrect: 3,
                    totalPractices: 2,
                    totalTimeSpentSec: 90
                ),
                HistorySessionSummary(
                    sessionDate: "2026-04-13",
                    totalListens: 4,
                    totalCorrect: 4,
                    totalPractices: 1,
                    totalTimeSpentSec: 70
                )
            ]
        )
        let viewModel = HistoryViewModel(dataService: dataService)

        await viewModel.loadHistory()

        XCTAssertEqual(viewModel.sessions.map(\.sessionDate), ["2026-04-13", "2026-04-12"])
        XCTAssertNil(viewModel.errorMessage)
    }

    func testLoadHistoryFailureExposesErrorMessage() async {
        let dataService = MockHistoryDataService(fetchError: DataServiceError.database("history failed"))
        let viewModel = HistoryViewModel(dataService: dataService)

        await viewModel.loadHistory()

        XCTAssertEqual(viewModel.sessions, [])
        XCTAssertEqual(viewModel.errorMessage, "Database error: history failed")
    }
}

actor MockHistoryDataService: HistoryDataServing {
    private let summaries: [HistorySessionSummary]
    private let fetchError: Error?

    init(summaries: [HistorySessionSummary] = [], fetchError: Error? = nil) {
        self.summaries = summaries
        self.fetchError = fetchError
    }

    func fetchHistorySessionSummaries() async throws -> [HistorySessionSummary] {
        if let fetchError {
            throw fetchError
        }

        return summaries
    }
}

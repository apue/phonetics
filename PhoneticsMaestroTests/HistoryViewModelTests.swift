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
}

actor MockHistoryDataService: HistoryDataServing {
    private let summaries: [HistorySessionSummary]

    init(summaries: [HistorySessionSummary]) {
        self.summaries = summaries
    }

    func fetchHistorySessionSummaries() async throws -> [HistorySessionSummary] {
        summaries
    }
}

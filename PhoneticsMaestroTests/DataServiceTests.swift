import XCTest
@testable import PhoneticsMaestro

final class DataServiceTests: XCTestCase {
    func testInitializeImportsSeedDataAndCreatesDatabase() async throws {
        let appSupportURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: appSupportURL) }

        let service = DataService(appSupportURL: appSupportURL)

        try await service.initialize()

        let databaseURL = await service.currentDatabaseURL()
        let pairCount = try await service.pairCount()
        let sentenceCount = try await service.sentenceCount()

        XCTAssertTrue(FileManager.default.fileExists(atPath: databaseURL.path))
        XCTAssertEqual(pairCount, 60)
        XCTAssertEqual(sentenceCount, 10)

        let firstPair = try await service.fetchNextPair()
        XCTAssertEqual(firstPair?.leftText, "but")
        XCTAssertEqual(firstPair?.rightText, "bat")
        XCTAssertEqual(firstPair?.phonemeContrast, "ʌ-æ")
    }

    func testFetchNextPairWrapsAroundWhenReachingTheEnd() async throws {
        let appSupportURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: appSupportURL) }

        let service = DataService(appSupportURL: appSupportURL)

        try await service.initialize()

        let wrappedPair = try await service.fetchNextPair(afterID: 10_000)
        XCTAssertEqual(wrappedPair?.leftText, "but")
        XCTAssertEqual(wrappedPair?.rightText, "bat")
    }

    func testFetchPreviousPairWrapsAroundWhenReachingTheBeginning() async throws {
        let appSupportURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: appSupportURL) }

        let service = DataService(appSupportURL: appSupportURL)
        try await service.initialize()

        let lastPair = try await service.fetchPreviousPair()
        let wrappedPair = try await service.fetchPreviousPair(beforeID: 1)
        XCTAssertEqual(wrappedPair?.id, lastPair?.id)
        XCTAssertEqual(wrappedPair?.leftText, lastPair?.leftText)
        XCTAssertEqual(wrappedPair?.rightText, lastPair?.rightText)
    }

    func testUpdatePairTagStatePersistsSavedAndHardFlags() async throws {
        let appSupportURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: appSupportURL) }

        let service = DataService(appSupportURL: appSupportURL)
        try await service.initialize()

        let initialState = try await service.fetchPairTagState(for: 1)
        XCTAssertEqual(initialState, TrainingTagState(isSaved: false, isHard: false))

        try await service.updatePairTagState(
            for: 1,
            sessionDate: "2026-04-13",
            isSaved: true,
            isHard: true
        )

        let updatedState = try await service.fetchPairTagState(for: 1)
        XCTAssertEqual(updatedState, TrainingTagState(isSaved: true, isHard: true))
    }

    func testUpdatePairSessionStatsPersistsCurrentCountsAndElapsedTime() async throws {
        let appSupportURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: appSupportURL) }

        let service = DataService(appSupportURL: appSupportURL)
        try await service.initialize()

        let initialStats = try await service.fetchPairSessionStats(for: 1, sessionDate: "2026-04-13")
        XCTAssertEqual(initialStats, SessionStats())

        let sessionStats = SessionStats(listens: 3, correct: 2, practices: 1, elapsedSeconds: 75)
        try await service.updatePairSessionStats(
            for: 1,
            sessionDate: "2026-04-13",
            stats: sessionStats,
            isSaved: true,
            isHard: false
        )

        let updatedStats = try await service.fetchPairSessionStats(for: 1, sessionDate: "2026-04-13")
        XCTAssertEqual(updatedStats, sessionStats)
        let updatedTags = try await service.fetchPairTagState(for: 1)
        XCTAssertEqual(updatedTags, TrainingTagState(isSaved: true, isHard: false))
    }

    func testFetchHistorySessionSummariesAggregatesByDate() async throws {
        let appSupportURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: appSupportURL) }

        let service = DataService(appSupportURL: appSupportURL)
        try await service.initialize()

        try await service.updatePairSessionStats(
            for: 1,
            sessionDate: "2026-04-12",
            stats: SessionStats(listens: 2, correct: 1, practices: 1, elapsedSeconds: 40),
            isSaved: false,
            isHard: false
        )
        try await service.updatePairSessionStats(
            for: 2,
            sessionDate: "2026-04-12",
            stats: SessionStats(listens: 3, correct: 2, practices: 2, elapsedSeconds: 50),
            isSaved: false,
            isHard: false
        )
        try await service.updatePairSessionStats(
            for: 3,
            sessionDate: "2026-04-13",
            stats: SessionStats(listens: 4, correct: 3, practices: 1, elapsedSeconds: 70),
            isSaved: false,
            isHard: false
        )

        let summaries = try await service.fetchHistorySessionSummaries()
        XCTAssertEqual(summaries.map(\.sessionDate), ["2026-04-13", "2026-04-12"])
        XCTAssertEqual(summaries[0].totalListens, 4)
        XCTAssertEqual(summaries[0].totalCorrect, 3)
        XCTAssertEqual(summaries[0].totalPractices, 1)
        XCTAssertEqual(summaries[0].totalTimeSpentSec, 70)
        XCTAssertEqual(summaries[1].totalListens, 5)
        XCTAssertEqual(summaries[1].totalCorrect, 3)
        XCTAssertEqual(summaries[1].totalPractices, 3)
        XCTAssertEqual(summaries[1].totalTimeSpentSec, 90)
    }

    private func makeTemporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

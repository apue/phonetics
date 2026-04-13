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

    private func makeTemporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

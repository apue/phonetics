import XCTest
@testable import PhoneticsCore

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

    func testFetchTrainingTargetsIncludesPairAndSentenceTargets() async throws {
        let appSupportURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: appSupportURL) }

        let service = DataService(appSupportURL: appSupportURL)
        try await service.initialize()

        let targets = try await service.fetchTrainingTargets()

        XCTAssertTrue(targets.contains { $0.id == "pair:ʌ-æ" })
        XCTAssertTrue(targets.contains { $0.id == "sentence:linking" })
        XCTAssertTrue(targets.contains { $0.id == "sentence:stress" })
    }

    func testFetchTrainingCardsBuildsSentenceComparisonCards() async throws {
        let appSupportURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: appSupportURL) }

        let service = DataService(appSupportURL: appSupportURL)
        try await service.initialize()

        let cards = try await service.fetchTrainingCards(forTargetID: "sentence:linking")

        XCTAssertEqual(cards.count, 2)
        XCTAssertEqual(cards.first?.itemType, "sentence")
        XCTAssertEqual(cards.first?.leftText, "Pick it up.")
        XCTAssertEqual(cards.first?.rightText, "Turn it on.")
    }

    func testBuildSentenceTrainingCardsSkipsSentencesWithoutIDs() async throws {
        let appSupportURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: appSupportURL) }

        let service = DataService(appSupportURL: appSupportURL)
        let sentences = [
            Sentence(id: nil, text: "Ignore me.", ipa: "/ɪɡˈnɔːr mi/", phenomenon: "linking", notes: nil, tier: .sentence),
            Sentence(id: 11, text: "Pick it up.", ipa: "/pɪk‿ɪt‿ʌp/", phenomenon: "linking", notes: nil, tier: .sentence),
            Sentence(id: 12, text: "Turn it on.", ipa: "/tɜːn‿ɪt‿ɒn/", phenomenon: "linking", notes: nil, tier: .sentence)
        ]

        let cards = await service.buildSentenceTrainingCards(
            targetID: "sentence:linking",
            phenomenon: "linking",
            sentences: sentences
        )

        XCTAssertEqual(cards.count, 2)
        XCTAssertEqual(cards.map(\.itemID), [11, 12])
        XCTAssertTrue(cards.allSatisfy { $0.itemID > 0 })
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

    func testGenericSentenceProgressPersistenceUsesItemTypeSentence() async throws {
        let appSupportURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: appSupportURL) }

        let service = DataService(appSupportURL: appSupportURL)
        try await service.initialize()

        try await service.updateTagState(
            itemType: "sentence",
            itemID: 1,
            sessionDate: "2026-04-13",
            isSaved: true,
            isHard: false
        )
        try await service.updateSessionStats(
            itemType: "sentence",
            itemID: 1,
            sessionDate: "2026-04-13",
            stats: SessionStats(listens: 2, correct: 1, practices: 1, elapsedSeconds: 20),
            isSaved: true,
            isHard: false
        )

        let state = try await service.fetchTagState(itemType: "sentence", itemID: 1)
        let stats = try await service.fetchSessionStats(itemType: "sentence", itemID: 1, sessionDate: "2026-04-13")
        XCTAssertEqual(state, TrainingTagState(isSaved: true, isHard: false))
        XCTAssertEqual(stats, SessionStats(listens: 2, correct: 1, practices: 1, elapsedSeconds: 20))
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

    func testFetchSettingsReturnsDefaultsBeforeFirstSave() async throws {
        let appSupportURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: appSupportURL) }

        let service = DataService(appSupportURL: appSupportURL)
        try await service.initialize()

        let settings = try await service.fetchSettings()
        XCTAssertEqual(settings, AppSettings())
    }

    func testUpdateSettingsPersistsVoiceMicrophoneAndABABInterval() async throws {
        let appSupportURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: appSupportURL) }

        let service = DataService(appSupportURL: appSupportURL)
        try await service.initialize()

        let updated = AppSettings(
            preferredVoiceName: "Samantha",
            preferredMicrophoneName: "Built-in Microphone",
            ababIntervalMilliseconds: 450
        )
        try await service.updateSettings(updated)

        let fetched = try await service.fetchSettings()
        XCTAssertEqual(fetched, updated)
    }

    func testFetchSettingsReturnsDismissedOnboardingFlagFromPersistedRow() async throws {
        let appSupportURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: appSupportURL) }

        let service = DataService(appSupportURL: appSupportURL)
        try await service.initialize()

        try await service.updateSettings(AppSettings(hasDismissedOnboarding: true))

        let settings = try await service.fetchSettings()
        XCTAssertTrue(settings.hasDismissedOnboarding)
    }

    func testUpdateSettingsPersistsDismissedOnboardingFlag() async throws {
        let appSupportURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: appSupportURL) }

        let service = DataService(appSupportURL: appSupportURL)
        try await service.initialize()

        let updated = AppSettings(hasDismissedOnboarding: true)
        try await service.updateSettings(updated)

        let fetched = try await service.fetchSettings()
        XCTAssertEqual(fetched, updated)
    }

    private func makeTemporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

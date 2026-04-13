import XCTest
@testable import PhoneticsMaestro

@MainActor
final class TrainingCardViewModelTests: XCTestCase {
    func testPlayRandomTestUpdatesListenCountAndWaitsForAnswer() async throws {
        let dataService = MockTrainingDataService()
        let audioService = MockTrainingAudioService(randomTestIndex: 1)
        let viewModel = TrainingCardViewModel(
            dataService: dataService,
            audioService: audioService
        )

        await viewModel.loadInitialPair()
        try await viewModel.playRandomTest()

        let randomTestRequests = await audioService.randomTestRequests()
        XCTAssertEqual(randomTestRequests, [["but", "bat"]])
        XCTAssertEqual(viewModel.sessionStats.listens, 1)
        XCTAssertEqual(viewModel.sessionStats.correct, 0)
        XCTAssertEqual(viewModel.perceptionState, .awaitingAnswer)
    }

    func testSubmitPerceptionGuessMarksCorrectAnswer() async throws {
        let dataService = MockTrainingDataService()
        let audioService = MockTrainingAudioService(randomTestIndex: 0)
        let viewModel = TrainingCardViewModel(
            dataService: dataService,
            audioService: audioService
        )

        await viewModel.loadInitialPair()
        try await viewModel.playRandomTest()
        await viewModel.submitPerceptionGuess(PairOption.left)

        XCTAssertEqual(viewModel.sessionStats.listens, 1)
        XCTAssertEqual(viewModel.sessionStats.correct, 1)
        XCTAssertEqual(viewModel.perceptionState, .correct(expected: .left))
    }

    func testSubmitPerceptionGuessMarksIncorrectAnswerAndPlaysCorrection() async throws {
        let dataService = MockTrainingDataService()
        let audioService = MockTrainingAudioService(randomTestIndex: 1)
        let viewModel = TrainingCardViewModel(
            dataService: dataService,
            audioService: audioService
        )

        await viewModel.loadInitialPair()
        try await viewModel.playRandomTest()
        await viewModel.submitPerceptionGuess(.left)

        let correctionRequests = await audioService.standardPlaybackRequests()
        XCTAssertEqual(viewModel.sessionStats.listens, 1)
        XCTAssertEqual(viewModel.sessionStats.correct, 0)
        XCTAssertEqual(viewModel.perceptionState, .incorrect(expected: .right))
        XCTAssertEqual(correctionRequests, ["bat"])
    }

    func testToggleRecordingStartsAndStopsRecordingAndUpdatesPracticeCount() async throws {
        let dataService = MockTrainingDataService()
        let audioService = MockTrainingAudioService(randomTestIndex: 0)
        let viewModel = TrainingCardViewModel(
            dataService: dataService,
            audioService: audioService,
            sessionDateProvider: { "2026-04-13" }
        )

        await viewModel.loadInitialPair()
        try await viewModel.toggleRecording()

        let attempts = await audioService.recordStartRequests().map(\.attempt)
        XCTAssertTrue(viewModel.isRecording)
        XCTAssertEqual(viewModel.sessionStats.practices, 0)
        XCTAssertEqual(attempts, [1])

        try await viewModel.toggleRecording()

        let stopRecordingCount = await audioService.stopRecordingCallCount()
        XCTAssertFalse(viewModel.isRecording)
        XCTAssertEqual(viewModel.sessionStats.practices, 1)
        XCTAssertEqual(stopRecordingCount, 1)
    }

    func testPracticePlaybackUsesSelectedTargetForStandardAndABAB() async throws {
        let dataService = MockTrainingDataService()
        let audioService = MockTrainingAudioService(randomTestIndex: 0)
        let viewModel = TrainingCardViewModel(
            dataService: dataService,
            audioService: audioService,
            sessionDateProvider: { "2026-04-13" }
        )

        await viewModel.loadInitialPair()
        viewModel.selectPracticeTarget(.right)

        try await viewModel.playSelectedStandard()
        try await viewModel.toggleRecording()
        try await viewModel.toggleRecording()
        try await viewModel.toggleABABLoop()

        let standardRequests = await audioService.standardPlaybackRequests()
        let ababRequests = await audioService.ababLoopRequests()
        XCTAssertEqual(standardRequests, ["bat"])
        XCTAssertEqual(ababRequests, ["bat"])
        XCTAssertTrue(viewModel.isABABLooping)
    }

    func testPlayUserRecordingAndStopABABLoopDelegateToAudioService() async throws {
        let dataService = MockTrainingDataService()
        let audioService = MockTrainingAudioService(randomTestIndex: 0)
        let viewModel = TrainingCardViewModel(
            dataService: dataService,
            audioService: audioService,
            sessionDateProvider: { "2026-04-13" }
        )

        await viewModel.loadInitialPair()
        try await viewModel.toggleRecording()
        try await viewModel.toggleRecording()
        try await viewModel.playUserRecording()
        try await viewModel.toggleABABLoop()
        await viewModel.stopPlayback()

        let userPlaybackCount = await audioService.userPlaybackCallCount()
        let stopCount = await audioService.stopCallCount()
        XCTAssertEqual(userPlaybackCount, 1)
        XCTAssertEqual(stopCount, 1)
        XCTAssertFalse(viewModel.isABABLooping)
    }

    func testLoadInitialPairReadsExistingTagState() async {
        let dataService = MockTrainingDataService(tagState: TrainingTagState(isSaved: true, isHard: false))
        let audioService = MockTrainingAudioService(randomTestIndex: 0)
        let viewModel = TrainingCardViewModel(
            dataService: dataService,
            audioService: audioService
        )

        await viewModel.loadInitialPair()

        XCTAssertTrue(viewModel.isSaved)
        XCTAssertFalse(viewModel.isHard)
    }

    func testToggleSaveAndHardPersistThroughDataService() async throws {
        let dataService = MockTrainingDataService()
        let audioService = MockTrainingAudioService(randomTestIndex: 0)
        let viewModel = TrainingCardViewModel(
            dataService: dataService,
            audioService: audioService,
            sessionDateProvider: { "2026-04-13" }
        )

        await viewModel.loadInitialPair()
        try await viewModel.toggleSaved()
        try await viewModel.toggleHard()

        let updates = await dataService.tagUpdates()
        XCTAssertEqual(updates.count, 2)
        XCTAssertEqual(updates[0].state, TrainingTagState(isSaved: true, isHard: false))
        XCTAssertEqual(updates[1].state, TrainingTagState(isSaved: true, isHard: true))
        XCTAssertTrue(viewModel.isSaved)
        XCTAssertTrue(viewModel.isHard)
    }

    func testToggleSavedRollsBackStateWhenPersistenceFails() async {
        let dataService = MockTrainingDataService(updateError: DataServiceError.database("write failed"))
        let audioService = MockTrainingAudioService(randomTestIndex: 0)
        let viewModel = TrainingCardViewModel(
            dataService: dataService,
            audioService: audioService,
            sessionDateProvider: { "2026-04-13" }
        )

        await viewModel.loadInitialPair()

        do {
            try await viewModel.toggleSaved()
            XCTFail("Expected save toggle to throw when persistence fails")
        } catch {
            guard case let DataServiceError.database(message) = error else {
                XCTFail("Expected database error, got \(error)")
                return
            }

            XCTAssertEqual(message, "write failed")
        }

        XCTAssertFalse(viewModel.isSaved)
        let updates = await dataService.tagUpdates()
        XCTAssertTrue(updates.isEmpty)
    }

    func testLoadInitialPairReadsExistingSessionStats() async {
        let existingStats = SessionStats(listens: 2, correct: 1, practices: 3, elapsedSeconds: 42)
        let dataService = MockTrainingDataService(sessionStatsByItemID: [1: existingStats])
        let audioService = MockTrainingAudioService(randomTestIndex: 0)
        let viewModel = TrainingCardViewModel(
            dataService: dataService,
            audioService: audioService,
            nowProvider: { Date(timeIntervalSince1970: 100) }
        )

        await viewModel.loadInitialPair()

        XCTAssertEqual(viewModel.sessionStats, existingStats)
    }

    func testRefreshElapsedTimeAddsSecondsSinceCardLoaded() async {
        let clock = TestClock(now: Date(timeIntervalSince1970: 100))
        let dataService = MockTrainingDataService()
        let audioService = MockTrainingAudioService(randomTestIndex: 0)
        let viewModel = TrainingCardViewModel(
            dataService: dataService,
            audioService: audioService,
            nowProvider: { clock.now }
        )

        await viewModel.loadInitialPair()
        clock.now = Date(timeIntervalSince1970: 165)
        viewModel.refreshElapsedTime()

        XCTAssertEqual(viewModel.sessionStats.elapsedSeconds, 65)
    }

    func testSessionStatsPersistAfterInteractions() async throws {
        let dataService = MockTrainingDataService()
        let audioService = MockTrainingAudioService(randomTestIndex: 0)
        let viewModel = TrainingCardViewModel(
            dataService: dataService,
            audioService: audioService,
            sessionDateProvider: { "2026-04-13" },
            nowProvider: { Date(timeIntervalSince1970: 100) }
        )

        await viewModel.loadInitialPair()
        try await viewModel.playRandomTest()
        await viewModel.submitPerceptionGuess(.left)
        try await viewModel.toggleRecording()
        try await viewModel.toggleRecording()

        let updates = await dataService.sessionStatsUpdates()
        XCTAssertEqual(updates.last?.itemID, 1)
        XCTAssertEqual(updates.last?.sessionDate, "2026-04-13")
        XCTAssertEqual(updates.last?.stats.listens, 1)
        XCTAssertEqual(updates.last?.stats.correct, 1)
        XCTAssertEqual(updates.last?.stats.practices, 1)
    }

    func testLoadNextPairPersistsElapsedTimeBeforeSwitching() async {
        let clock = TestClock(now: Date(timeIntervalSince1970: 100))
        let dataService = MockTrainingDataService()
        let audioService = MockTrainingAudioService(randomTestIndex: 0)
        let viewModel = TrainingCardViewModel(
            dataService: dataService,
            audioService: audioService,
            sessionDateProvider: { "2026-04-13" },
            nowProvider: { clock.now }
        )

        await viewModel.loadInitialPair()
        clock.now = Date(timeIntervalSince1970: 112)
        await viewModel.loadNextPair()

        let updates = await dataService.sessionStatsUpdates()
        XCTAssertEqual(updates.last?.itemID, 1)
        XCTAssertEqual(updates.last?.stats.elapsedSeconds, 12)
        XCTAssertEqual(viewModel.currentPair?.id, 2)
        XCTAssertEqual(viewModel.sessionStats, SessionStats())
    }
}

actor MockTrainingDataService: TrainingDataServing {
    private let tagState: TrainingTagState
    private let sessionStatsByItemID: [Int64: SessionStats]
    private let updateError: Error?
    private var updates: [(itemID: Int64, sessionDate: String, state: TrainingTagState)] = []
    private var sessionUpdates: [(itemID: Int64, sessionDate: String, stats: SessionStats, isSaved: Bool, isHard: Bool)] = []

    init(
        tagState: TrainingTagState = TrainingTagState(isSaved: false, isHard: false),
        sessionStatsByItemID: [Int64: SessionStats] = [:],
        updateError: Error? = nil
    ) {
        self.tagState = tagState
        self.sessionStatsByItemID = sessionStatsByItemID
        self.updateError = updateError
    }

    func fetchNextPair(afterID: Int64?) async throws -> PhonePair? {
        switch afterID {
        case 1:
            PhonePair(
                id: 2,
                phonemeContrast: "ɪ-iː",
                tier: .word,
                difficulty: 1,
                leftText: "ship",
                leftIPA: "/ʃɪp/",
                rightText: "sheep",
                rightIPA: "/ʃiːp/"
            )
        default:
            PhonePair(
                id: 1,
                phonemeContrast: "ʌ-æ",
                tier: .word,
                difficulty: 1,
                leftText: "but",
                leftIPA: "/bʌt/",
                rightText: "bat",
                rightIPA: "/bæt/"
            )
        }
    }

    func fetchPairTagState(for _: Int64) async throws -> TrainingTagState {
        if let latest = updates.last?.state {
            return latest
        }

        return tagState
    }

    func updatePairTagState(
        for itemID: Int64,
        sessionDate: String,
        isSaved: Bool,
        isHard: Bool
    ) async throws {
        if let updateError {
            throw updateError
        }

        updates.append((itemID, sessionDate, TrainingTagState(isSaved: isSaved, isHard: isHard)))
    }

    func tagUpdates() -> [(itemID: Int64, sessionDate: String, state: TrainingTagState)] {
        updates
    }

    func fetchPairSessionStats(for itemID: Int64, sessionDate _: String) async throws -> SessionStats {
        if let latest = sessionUpdates.last(where: { $0.itemID == itemID })?.stats {
            return latest
        }

        return sessionStatsByItemID[itemID] ?? SessionStats()
    }

    func updatePairSessionStats(
        for itemID: Int64,
        sessionDate: String,
        stats: SessionStats,
        isSaved: Bool,
        isHard: Bool
    ) async throws {
        if let updateError {
            throw updateError
        }

        sessionUpdates.append((itemID, sessionDate, stats, isSaved, isHard))
    }

    func sessionStatsUpdates() -> [(itemID: Int64, sessionDate: String, stats: SessionStats, isSaved: Bool, isHard: Bool)] {
        sessionUpdates
    }
}

actor MockTrainingAudioService: TrainingAudioServing {
    private let randomTestIndex: Int
    private var randomRequests: [[String]] = []
    private var standardRequests: [String] = []
    private var recordRequests: [(itemType: String, itemID: Int64, attempt: Int, sessionDate: String)] = []
    private var stopRecordingCount = 0
    private var userPlaybackCount = 0
    private var ababRequests: [String] = []
    private var stopCount = 0

    init(randomTestIndex: Int) {
        self.randomTestIndex = randomTestIndex
    }

    func playRandomTest(options: [String]) async throws -> Int {
        randomRequests.append(options)
        return randomTestIndex
    }

    func playStandard(for text: String) async throws {
        standardRequests.append(text)
    }

    func startRecording(
        itemType: String,
        itemID: Int64,
        attempt: Int,
        sessionDate: String
    ) async throws -> URL {
        recordRequests.append((itemType, itemID, attempt, sessionDate))
        return URL(fileURLWithPath: "/tmp/\(itemType)-\(itemID)-attempt-\(attempt).caf")
    }

    func stopRecording() async throws -> URL {
        stopRecordingCount += 1
        return URL(fileURLWithPath: "/tmp/pair-1-attempt-\(stopRecordingCount).caf")
    }

    func playUserRecording() async throws {
        userPlaybackCount += 1
    }

    func startABABLoop(standardText: String) async throws {
        ababRequests.append(standardText)
    }

    func stop() async {
        stopCount += 1
    }

    func randomTestRequests() -> [[String]] {
        randomRequests
    }

    func standardPlaybackRequests() -> [String] {
        standardRequests
    }

    func recordStartRequests() -> [(itemType: String, itemID: Int64, attempt: Int, sessionDate: String)] {
        recordRequests
    }

    func stopRecordingCallCount() -> Int {
        stopRecordingCount
    }

    func userPlaybackCallCount() -> Int {
        userPlaybackCount
    }

    func ababLoopRequests() -> [String] {
        ababRequests
    }

    func stopCallCount() -> Int {
        stopCount
    }
}

private final class TestClock: @unchecked Sendable {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}

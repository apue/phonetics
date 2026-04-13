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
        await viewModel.submitPerceptionGuess(.left)

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
}

actor MockTrainingDataService: TrainingDataServing {
    func fetchNextPair(afterID _: Int64?) async throws -> PhonePair? {
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

actor MockTrainingAudioService: TrainingAudioServing {
    private let randomTestIndex: Int
    private var randomRequests: [[String]] = []
    private var standardRequests: [String] = []

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

    func randomTestRequests() -> [[String]] {
        randomRequests
    }

    func standardPlaybackRequests() -> [String] {
        standardRequests
    }
}

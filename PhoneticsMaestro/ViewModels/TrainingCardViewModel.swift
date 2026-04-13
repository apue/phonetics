import Observation

@MainActor
@Observable
final class TrainingCardViewModel {
    var currentPair: PhonePair?
    var isLoading = false
    var errorMessage: String?
    var perceptionState: PerceptionState = .idle
    var sessionStats = SessionStats()

    private let dataService: any TrainingDataServing
    private let audioService: any TrainingAudioServing
    private var pendingAnswer: PairOption?

    init(
        dataService: any TrainingDataServing = DataService.shared,
        audioService: any TrainingAudioServing = AudioService.shared
    ) {
        self.dataService = dataService
        self.audioService = audioService
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

    func playRandomTest() async throws {
        guard let currentPair else {
            errorMessage = "Load a training pair before starting a random test."
            return
        }

        let selectedIndex = try await audioService.playRandomTest(
            options: [currentPair.leftText, currentPair.rightText]
        )

        pendingAnswer = selectedIndex == 0 ? .left : .right
        sessionStats.listens += 1
        perceptionState = .awaitingAnswer
        errorMessage = nil
    }

    func submitPerceptionGuess(_ guess: PairOption) async {
        guard let expected = pendingAnswer, let currentPair else {
            return
        }

        pendingAnswer = nil

        if guess == expected {
            sessionStats.correct += 1
            perceptionState = .correct(expected: expected)
            return
        }

        perceptionState = .incorrect(expected: expected)

        do {
            try await audioService.playStandard(for: text(for: expected, pair: currentPair))
        } catch {
            errorMessage = error.localizedDescription
        }
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
            pendingAnswer = nil
            perceptionState = .idle
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func text(for option: PairOption, pair: PhonePair) -> String {
        switch option {
        case .left:
            return pair.leftText
        case .right:
            return pair.rightText
        }
    }
}

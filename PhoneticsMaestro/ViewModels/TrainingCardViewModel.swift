import Foundation
import Observation

@MainActor
@Observable
final class TrainingCardViewModel {
    var currentPair: PhonePair?
    var isLoading = false
    var errorMessage: String?
    var perceptionState: PerceptionState = .idle
    var sessionStats = SessionStats()
    var selectedPracticeTarget: PairOption = .left
    var isRecording = false
    var isABABLooping = false
    var isSaved = false
    var isHard = false

    private let dataService: any TrainingDataServing
    private let audioService: any TrainingAudioServing
    private let sessionDateProvider: @Sendable () -> String
    private var pendingAnswer: PairOption?

    init(
        dataService: any TrainingDataServing = DataService.shared,
        audioService: any TrainingAudioServing = AudioService.shared,
        sessionDateProvider: @escaping @Sendable () -> String = {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: Date())
        }
    ) {
        self.dataService = dataService
        self.audioService = audioService
        self.sessionDateProvider = sessionDateProvider
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

    func selectPracticeTarget(_ target: PairOption) {
        selectedPracticeTarget = target
    }

    func toggleRecording() async throws {
        guard let currentPair else {
            errorMessage = "Load a training pair before recording."
            return
        }

        if isRecording {
            _ = try await audioService.stopRecording()
            isRecording = false
            sessionStats.practices += 1
            return
        }

        _ = try await audioService.startRecording(
            itemType: "pair",
            itemID: currentPair.id,
            attempt: sessionStats.practices + 1,
            sessionDate: sessionDateProvider()
        )
        isRecording = true
        isABABLooping = false
        errorMessage = nil
    }

    func playSelectedStandard() async throws {
        guard let currentPair else {
            errorMessage = "Load a training pair before playback."
            return
        }

        try await audioService.playStandard(for: text(for: selectedPracticeTarget, pair: currentPair))
    }

    func playUserRecording() async throws {
        try await audioService.playUserRecording()
    }

    func toggleABABLoop() async throws {
        guard let currentPair else {
            errorMessage = "Load a training pair before starting A/B playback."
            return
        }

        if isABABLooping {
            await audioService.stop()
            isABABLooping = false
            return
        }

        try await audioService.startABABLoop(
            standardText: text(for: selectedPracticeTarget, pair: currentPair)
        )
        isABABLooping = true
    }

    func stopPlayback() async {
        await audioService.stop()
        isABABLooping = false
    }

    func toggleSaved() async throws {
        guard let currentPair else {
            errorMessage = "Load a training pair before saving."
            return
        }

        let nextValue = !isSaved

        do {
            try await dataService.updatePairTagState(
                for: currentPair.id,
                sessionDate: sessionDateProvider(),
                isSaved: nextValue,
                isHard: isHard
            )
            isSaved = nextValue
        } catch {
            isSaved = !nextValue
            throw error
        }
    }

    func toggleHard() async throws {
        guard let currentPair else {
            errorMessage = "Load a training pair before marking difficulty."
            return
        }

        let nextValue = !isHard

        do {
            try await dataService.updatePairTagState(
                for: currentPair.id,
                sessionDate: sessionDateProvider(),
                isSaved: isSaved,
                isHard: nextValue
            )
            isHard = nextValue
        } catch {
            isHard = !nextValue
            throw error
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
            let pair = try await dataService.fetchNextPair(afterID: afterID)
            currentPair = pair
            pendingAnswer = nil
            perceptionState = .idle
            selectedPracticeTarget = .left
            isRecording = false
            isABABLooping = false
            if let pair {
                let tagState = try await dataService.fetchPairTagState(for: pair.id)
                isSaved = tagState.isSaved
                isHard = tagState.isHard
            } else {
                isSaved = false
                isHard = false
            }
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

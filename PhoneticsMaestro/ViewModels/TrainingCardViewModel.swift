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
    private let nowProvider: @Sendable () -> Date
    private var pendingAnswer: PairOption?
    private var timerTask: Task<Void, Never>?
    private var baseElapsedSeconds = 0
    private var cardStartDate: Date?

    init(
        dataService: any TrainingDataServing = DataService.shared,
        audioService: any TrainingAudioServing = AudioService.shared,
        sessionDateProvider: @escaping @Sendable () -> String = {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: Date())
        },
        nowProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.dataService = dataService
        self.audioService = audioService
        self.sessionDateProvider = sessionDateProvider
        self.nowProvider = nowProvider
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
        try await persistSessionStats()
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
            do {
                try await persistSessionStats()
            } catch {
                errorMessage = error.localizedDescription
            }
            return
        }

        perceptionState = .incorrect(expected: expected)
        do {
            try await persistSessionStats()
        } catch {
            errorMessage = error.localizedDescription
        }

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
            try await persistSessionStats()
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

    func refreshElapsedTime() {
        guard let cardStartDate else {
            sessionStats.elapsedSeconds = baseElapsedSeconds
            return
        }

        let elapsed = max(0, Int(nowProvider().timeIntervalSince(cardStartDate)))
        sessionStats.elapsedSeconds = baseElapsedSeconds + elapsed
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
            try await persistCurrentPairProgressIfNeeded()
            let pair = try await dataService.fetchNextPair(afterID: afterID)
            currentPair = pair
            pendingAnswer = nil
            perceptionState = .idle
            selectedPracticeTarget = .left
            isRecording = false
            isABABLooping = false
            if let pair {
                let tagState = try await dataService.fetchPairTagState(for: pair.id)
                sessionStats = try await dataService.fetchPairSessionStats(
                    for: pair.id,
                    sessionDate: sessionDateProvider()
                )
                isSaved = tagState.isSaved
                isHard = tagState.isHard
                baseElapsedSeconds = sessionStats.elapsedSeconds
                cardStartDate = nowProvider()
                startTimer()
            } else {
                timerTask?.cancel()
                timerTask = nil
                sessionStats = SessionStats()
                baseElapsedSeconds = 0
                cardStartDate = nil
                isSaved = false
                isHard = false
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persistCurrentPairProgressIfNeeded() async throws {
        guard currentPair != nil else {
            return
        }

        try await persistSessionStats()
    }

    private func persistSessionStats() async throws {
        guard let currentPair else {
            return
        }

        refreshElapsedTime()
        try await dataService.updatePairSessionStats(
            for: currentPair.id,
            sessionDate: sessionDateProvider(),
            stats: sessionStats,
            isSaved: isSaved,
            isHard: isHard
        )
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else {
                    return
                }

                self.handleTimerTick()
            }
        }
    }

    private func handleTimerTick() {
        refreshElapsedTime()
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

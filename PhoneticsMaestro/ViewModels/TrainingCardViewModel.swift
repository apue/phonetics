import Foundation
import Observation

@MainActor
@Observable
final class TrainingCardViewModel {
    var targets: [TrainingTargetSummary] = []
    var selectedTargetID: String?
    var currentCardItems: [TrainingCardItem] = []
    var currentCardIndex = 0
    var isLoading = false
    var errorMessage: String?
    var perceptionState: PerceptionState = .idle
    var sessionStats = SessionStats()
    var selectedPracticeTarget: PairOption = .left
    var interactionState: TrainingInteractionState = .idle
    var isSaved = false
    var isHard = false
    var playbackRate: Float = 1.0
    var ababIntervalMilliseconds = 300
    var isRecording: Bool {
        interactionState == .recording
    }
    var isABABLooping: Bool {
        guard case let .playing(control) = interactionState else {
            return false
        }

        if case .ababLoop = control {
            return true
        }

        return false
    }
    var activePlaybackControl: TrainingPlaybackControl? {
        guard case let .playing(control) = interactionState else {
            return nil
        }

        return control
    }
    var isPlaybackActive: Bool {
        activePlaybackControl != nil
    }
    var feedbackHighlight: TrainingFeedbackHighlight? {
        switch perceptionState {
        case .correct:
            return .success
        case .incorrect:
            return .error
        case .idle, .awaitingAnswer:
            return nil
        }
    }

    var currentTarget: TrainingTargetSummary? {
        guard let selectedTargetID else {
            return nil
        }

        return targets.first { $0.id == selectedTargetID }
    }

    var currentCard: TrainingCardItem? {
        guard currentCardItems.indices.contains(currentCardIndex) else {
            return nil
        }

        return currentCardItems[currentCardIndex]
    }

    var currentPair: PhonePair? {
        guard let currentCard, currentCard.kind == .pair else {
            return nil
        }

        return PhonePair(
            id: currentCard.itemID,
            phonemeContrast: currentTarget?.title ?? currentCard.subtitle,
            tier: .word,
            difficulty: 1,
            leftText: currentCard.leftText,
            leftIPA: currentCard.leftIPA ?? "",
            rightText: currentCard.rightText,
            rightIPA: currentCard.rightIPA ?? ""
        )
    }

    private let dataService: any TrainingDataServing
    private let audioService: any TrainingAudioServing
    private let sessionDateProvider: @Sendable () -> String
    private let nowProvider: @Sendable () -> Date
    private var pendingAnswer: PairOption?
    private var timerTask: Task<Void, Never>?
    private var baseElapsedSeconds = 0
    private var cardStartDate: Date?
    private var playbackGeneration = 0
    private var currentCardIdentity: TrainingCardIdentity? {
        guard let currentCard else {
            return nil
        }

        return TrainingCardIdentity(card: currentCard)
    }

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

    func applySettings(_ settings: AppSettings) {
        ababIntervalMilliseconds = settings.ababIntervalMilliseconds
    }

    func loadInitialState() async {
        await loadInitialState(forceReload: true)
    }

    func loadInitialPair() async {
        await loadInitialState()
    }

    func loadInitialPairIfNeeded() async {
        guard currentCard == nil else {
            return
        }

        await loadInitialState(forceReload: false)
    }

    func loadNextCard() async {
        await navigate(direction: 1)
    }

    func loadNextPair() async {
        await loadNextCard()
    }

    func loadPreviousCard() async {
        await navigate(direction: -1)
    }

    func loadPreviousPair() async {
        await loadPreviousCard()
    }

    func reloadCurrentTarget() async {
        await selectTarget(id: selectedTargetID, forceReload: false)
    }

    func selectTarget(id: String?) async {
        await selectTarget(id: id, forceReload: false)
    }

    func tapTargetCard(_ option: PairOption) async {
        guard let currentCard else {
            errorMessage = "Load a training card before playback."
            return
        }

        selectedPracticeTarget = option

        do {
            try await runPlayback(control: .targetCard(option)) {
                try await self.audioService.playStandard(for: self.text(for: option, card: currentCard))
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func playRandomTest() async throws {
        guard let currentCard else {
            errorMessage = "Load a training card before starting a random test."
            return
        }

        let playbackCard = currentCard
        let playbackCardIdentity = TrainingCardIdentity(card: playbackCard)

        let selectedIndex = try await runPlayback(control: .randomTest) {
            try await self.audioService.playRandomTest(
                options: [playbackCard.leftText, playbackCard.rightText]
            )
        }

        guard currentCardIdentity == playbackCardIdentity else {
            return
        }

        pendingAnswer = selectedIndex == 0 ? .left : .right
        sessionStats.listens += 1
        perceptionState = .awaitingAnswer
        try await persistSessionStats()
        errorMessage = nil
    }

    func submitPerceptionGuess(_ guess: PairOption) async {
        guard let expected = pendingAnswer, let currentCard else {
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
            try await runPlayback(control: .practiceStandard(expected)) {
                try await self.audioService.playStandard(for: self.text(for: expected, card: currentCard))
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectPracticeTarget(_ target: PairOption) {
        selectedPracticeTarget = target
    }

    func toggleRecording() async throws {
        guard let currentCard else {
            errorMessage = "Load a training card before recording."
            return
        }

        if isRecording {
            _ = try await audioService.stopRecording()
            interactionState = .idle
            sessionStats.practices += 1
            try await persistSessionStats()
            return
        }

        if isPlaybackActive {
            await audioService.stop()
            clearPlaybackState()
        }

        _ = try await audioService.startRecording(
            itemType: currentCard.itemType,
            itemID: currentCard.itemID,
            attempt: sessionStats.practices + 1,
            sessionDate: sessionDateProvider()
        )
        interactionState = .recording
        errorMessage = nil
    }

    func playSelectedStandard() async throws {
        guard let currentCard else {
            errorMessage = "Load a training card before playback."
            return
        }

        try await runPlayback(control: .practiceStandard(selectedPracticeTarget)) {
            try await self.audioService.playStandard(
                for: self.text(for: selectedPracticeTarget, card: currentCard),
                rate: self.playbackRate
            )
        }
    }

    func playUserRecording() async throws {
        try await runPlayback(control: .userRecording) {
            try await self.audioService.playUserRecording(rate: self.playbackRate)
        }
    }

    func toggleABABLoop() async throws {
        guard let currentCard else {
            errorMessage = "Load a training card before starting A/B playback."
            return
        }

        if isABABLooping {
            await stopPlayback()
            return
        }

        try await audioService.startABABLoop(
            standardText: text(for: selectedPracticeTarget, card: currentCard),
            rate: playbackRate,
            silenceNanoseconds: UInt64(ababIntervalMilliseconds) * 1_000_000
        )
        beginPlayback(control: .ababLoop(selectedPracticeTarget))
        errorMessage = nil
    }

    func stopPlayback() async {
        await audioService.stop()
        clearPlaybackState()
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
        guard let currentCard else {
            errorMessage = "Load a training card before saving."
            return
        }

        let nextValue = !isSaved

        do {
            try await dataService.updateTagState(
                itemType: currentCard.itemType,
                itemID: currentCard.itemID,
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
        guard let currentCard else {
            errorMessage = "Load a training card before marking difficulty."
            return
        }

        let nextValue = !isHard

        do {
            try await dataService.updateTagState(
                itemType: currentCard.itemType,
                itemID: currentCard.itemID,
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

    private func loadInitialState(forceReload: Bool) async {
        guard !isLoading else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            if forceReload || targets.isEmpty {
                targets = try await dataService.fetchTrainingTargets()
            }

            let targetID = selectedTargetID ?? targets.first?.id
            await selectTarget(id: targetID, forceReload: forceReload)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func selectTarget(id: String?, forceReload: Bool) async {
        guard let id else {
            clearCurrentCardState()
            return
        }

        do {
            try await prepareForCardNavigation()
            try await persistCurrentCardProgressIfNeeded()

            if forceReload || currentCardItems.isEmpty || selectedTargetID != id {
                currentCardItems = try await dataService.fetchTrainingCards(forTargetID: id)
            }

            selectedTargetID = id
            currentCardIndex = 0
            try await applyCurrentCard()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func navigate(direction: Int) async {
        guard !isLoading else {
            return
        }

        guard !currentCardItems.isEmpty else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await prepareForCardNavigation()
            try await persistCurrentCardProgressIfNeeded()
            let nextIndex = wrappedIndex(from: currentCardIndex, direction: direction, count: currentCardItems.count)
            currentCardIndex = nextIndex
            try await applyCurrentCard()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func prepareForCardNavigation() async throws {
        if isPlaybackActive {
            await audioService.stop()
            clearPlaybackState()
        }

        if isRecording {
            _ = try await audioService.stopRecording()
            interactionState = .idle
            sessionStats.practices += 1
        }
    }

    private func persistCurrentCardProgressIfNeeded() async throws {
        guard currentCard != nil else {
            return
        }

        try await persistSessionStats()
    }

    private func applyCurrentCard() async throws {
        pendingAnswer = nil
        perceptionState = .idle
        selectedPracticeTarget = .left
        interactionState = .idle

        guard let currentCard else {
            clearCurrentCardState()
            return
        }

        let tagState = try await dataService.fetchTagState(itemType: currentCard.itemType, itemID: currentCard.itemID)
        sessionStats = try await dataService.fetchSessionStats(
            itemType: currentCard.itemType,
            itemID: currentCard.itemID,
            sessionDate: sessionDateProvider()
        )
        isSaved = tagState.isSaved
        isHard = tagState.isHard
        baseElapsedSeconds = sessionStats.elapsedSeconds
        cardStartDate = nowProvider()
        startTimer()
        errorMessage = nil
    }

    private func clearCurrentCardState() {
        timerTask?.cancel()
        timerTask = nil
        currentCardItems = []
        currentCardIndex = 0
        sessionStats = SessionStats()
        baseElapsedSeconds = 0
        cardStartDate = nil
        isSaved = false
        isHard = false
        selectedTargetID = nil
    }

    private func persistSessionStats() async throws {
        guard let currentCard else {
            return
        }

        refreshElapsedTime()
        try await dataService.updateSessionStats(
            itemType: currentCard.itemType,
            itemID: currentCard.itemID,
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

    private func beginPlayback(control: TrainingPlaybackControl) {
        playbackGeneration += 1
        interactionState = .playing(control: control)
    }

    private func clearPlaybackState() {
        playbackGeneration += 1
        interactionState = .idle
    }

    private func finishPlaybackIfCurrent(generation: Int) {
        guard playbackGeneration == generation else {
            return
        }

        interactionState = .idle
    }

    private func runPlayback<T>(
        control: TrainingPlaybackControl,
        operation: () async throws -> T
    ) async throws -> T {
        beginPlayback(control: control)
        let generation = playbackGeneration

        do {
            let result = try await operation()
            finishPlaybackIfCurrent(generation: generation)
            return result
        } catch {
            finishPlaybackIfCurrent(generation: generation)
            throw error
        }
    }

    private func text(for option: PairOption, card: TrainingCardItem) -> String {
        switch option {
        case .left:
            return card.leftText
        case .right:
            return card.rightText
        }
    }

    private func wrappedIndex(from current: Int, direction: Int, count: Int) -> Int {
        guard count > 0 else {
            return 0
        }

        return (current + direction + count) % count
    }
}

private struct TrainingCardIdentity: Equatable {
    let targetID: String
    let itemType: String
    let itemID: Int64

    init(card: TrainingCardItem) {
        targetID = card.targetID
        itemType = card.itemType
        itemID = card.itemID
    }
}

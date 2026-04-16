import Foundation

actor AudioService {
    static let shared = AudioService()

    private let platformClient: any AudioPlatformClient
    private let fileManager: FileManager
    private let appSupportURL: URL
    private let randomIndex: @Sendable (Int) -> Int

    private var state: AudioState = .idle
    private var lastRecordingURL: URL?
    private var ababTask: Task<Void, Never>?
    private var playbackGeneration = 0

    init(
        platformClient: any AudioPlatformClient = SystemAudioPlatformClient(),
        fileManager: FileManager = .default,
        appSupportURL: URL? = nil,
        randomIndex: @escaping @Sendable (Int) -> Int = { upperBound in
            Int.random(in: 0 ..< upperBound)
        }
    ) {
        self.platformClient = platformClient
        self.fileManager = fileManager
        self.appSupportURL = appSupportURL ?? AppPaths.applicationSupportDirectory(fileManager: fileManager)
        self.randomIndex = randomIndex
    }

    func currentState() -> AudioState {
        state
    }

    func startRecording(
        itemType: String,
        itemID: Int64,
        attempt: Int,
        sessionDate: String
    ) async throws -> URL {
        try await prepareForRecording(action: "startRecording")

        let hasPermission = await platformClient.requestRecordPermission()
        guard hasPermission else {
            throw AudioServiceError.microphonePermissionDenied
        }

        let recordingURL = recordingURL(
            itemType: itemType,
            itemID: itemID,
            attempt: attempt,
            sessionDate: sessionDate
        )

        do {
            try fileManager.createDirectory(
                at: recordingURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            transition(to: .recording(recordingURL: recordingURL))
            try await platformClient.startRecording(to: recordingURL)
            return recordingURL
        } catch let error as AudioServiceError {
            transition(to: .idle)
            throw error
        } catch {
            transition(to: .idle)
            throw AudioServiceError.recordingFailed(error.localizedDescription)
        }
    }

    func stopRecording() async throws -> URL {
        guard case let .recording(recordingURL) = state else {
            throw AudioServiceError.illegalTransition(currentState: state, attemptedAction: "stopRecording")
        }

        do {
            try await platformClient.stopRecording()
            lastRecordingURL = recordingURL
            transition(to: .idle)
            return recordingURL
        } catch let error as AudioServiceError {
            transition(to: .idle)
            throw error
        } catch {
            transition(to: .idle)
            throw AudioServiceError.recordingFailed(error.localizedDescription)
        }
    }

    func playStandard(for text: String, voiceIdentifier: String? = nil, rate: Float = 1.0) async throws {
        let generation = try await beginPlayback(action: "playStandard", source: .standard)

        do {
            try await platformClient.playSpeech(text: text, voiceIdentifier: voiceIdentifier, rate: rate)
        } catch let error as AudioServiceError {
            finishPlaybackIfCurrent(generation: generation)
            throw error
        } catch {
            finishPlaybackIfCurrent(generation: generation)
            throw AudioServiceError.playbackFailed(error.localizedDescription)
        }

        finishPlaybackIfCurrent(generation: generation)
    }

    func playRandomTest(
        options: [String],
        voiceIdentifier: String? = nil,
        rate: Float = 1.0
    ) async throws -> Int {
        guard options.count >= 2 else {
            throw AudioServiceError.invalidRandomTestOptions
        }

        let selectedIndex = randomIndex(options.count)
        let generation = try await beginPlayback(action: "playRandomTest", source: .randomTest)

        do {
            try await platformClient.playSpeech(
                text: options[selectedIndex],
                voiceIdentifier: voiceIdentifier,
                rate: rate
            )
        } catch let error as AudioServiceError {
            finishPlaybackIfCurrent(generation: generation)
            throw error
        } catch {
            finishPlaybackIfCurrent(generation: generation)
            throw AudioServiceError.playbackFailed(error.localizedDescription)
        }

        finishPlaybackIfCurrent(generation: generation)
        return selectedIndex
    }

    func playUserRecording(rate: Float = 1.0) async throws {
        try ensureNotRecording(for: "playUserRecording")
        let recordingURL = try await requireRecordingURL()
        let generation = try await beginPlayback(action: "playUserRecording", source: .userRecording)

        do {
            try await platformClient.playAudioFile(at: recordingURL, rate: rate)
        } catch let error as AudioServiceError {
            finishPlaybackIfCurrent(generation: generation)
            throw error
        } catch {
            finishPlaybackIfCurrent(generation: generation)
            throw AudioServiceError.playbackFailed(error.localizedDescription)
        }

        finishPlaybackIfCurrent(generation: generation)
    }

    func startABABLoop(
        standardText: String,
        voiceIdentifier: String? = nil,
        rate: Float = 1.0,
        silenceNanoseconds: UInt64 = 300_000_000
    ) async throws {
        try ensureNotRecording(for: "startABABLoop")
        let recordingURL = try await requireRecordingURL()
        let generation = try await beginPlayback(action: "startABABLoop", source: .ababLoop)

        ababTask?.cancel()
        ababTask = Task {
            await runABABLoop(
                generation: generation,
                standardText: standardText,
                voiceIdentifier: voiceIdentifier,
                recordingURL: recordingURL,
                rate: rate,
                silenceNanoseconds: silenceNanoseconds
            )
        }
    }

    func stop() async {
        await interruptPlayback()
    }

    private func ensureNotRecording(for action: String) throws {
        if case .recording = state {
            throw AudioServiceError.illegalTransition(currentState: state, attemptedAction: action)
        }
    }

    private func prepareForRecording(action: String) async throws {
        switch state {
        case .idle:
            return
        case .recording:
            throw AudioServiceError.illegalTransition(currentState: state, attemptedAction: action)
        case .playing:
            await interruptPlayback()
        }
    }

    private func requireRecordingURL() async throws -> URL {
        guard let lastRecordingURL, await platformClient.fileExists(at: lastRecordingURL) else {
            throw AudioServiceError.missingRecording
        }

        return lastRecordingURL
    }

    private func transition(to newState: AudioState) {
        state = newState
    }

    private func beginPlayback(action: String, source: AudioPlaybackSource) async throws -> Int {
        switch state {
        case .idle:
            break
        case .recording:
            throw AudioServiceError.illegalTransition(currentState: state, attemptedAction: action)
        case .playing:
            await interruptPlayback()
        }

        playbackGeneration += 1
        let generation = playbackGeneration
        transition(to: .playing(source: source))
        return generation
    }

    private func finishPlaybackIfCurrent(generation: Int) {
        guard playbackGeneration == generation else {
            return
        }

        if case .playing = state {
            transition(to: .idle)
        }
    }

    private func interruptPlayback() async {
        guard case .playing = state else {
            return
        }

        playbackGeneration += 1
        ababTask?.cancel()
        ababTask = nil
        await platformClient.stopPlayback()

        if case .playing = state {
            transition(to: .idle)
        }
    }

    private func recordingURL(
        itemType: String,
        itemID: Int64,
        attempt: Int,
        sessionDate: String
    ) -> URL {
        AppPaths.recordingsDirectory(appSupportURL: appSupportURL)
            .appending(path: sessionDate, directoryHint: .isDirectory)
            .appending(path: "\(itemType)-\(itemID)-attempt-\(attempt).caf")
    }

    private func runABABLoop(
        generation: Int,
        standardText: String,
        voiceIdentifier: String?,
        recordingURL: URL,
        rate: Float,
        silenceNanoseconds: UInt64
    ) async {
        defer {
            ababTask = nil

            if playbackGeneration == generation, case .playing(source: .ababLoop) = state {
                transition(to: .idle)
            }
        }

        while !Task.isCancelled {
            do {
                try await platformClient.playSpeech(text: standardText, voiceIdentifier: voiceIdentifier, rate: rate)
                try await Task.sleep(nanoseconds: silenceNanoseconds)
                try await platformClient.playAudioFile(at: recordingURL, rate: rate)
                try await Task.sleep(nanoseconds: silenceNanoseconds)
            } catch {
                break
            }
        }
    }
}

extension AudioService: TrainingAudioServing {
    func playRandomTest(options: [String]) async throws -> Int {
        try await playRandomTest(options: options, voiceIdentifier: nil, rate: 1.0)
    }

    func playStandard(for text: String) async throws {
        try await playStandard(for: text, voiceIdentifier: nil, rate: 1.0)
    }

    func playStandard(for text: String, rate: Float) async throws {
        try await playStandard(for: text, voiceIdentifier: nil, rate: rate)
    }

    func playUserRecording() async throws {
        try await playUserRecording(rate: 1.0)
    }

    func startABABLoop(standardText: String) async throws {
        try await startABABLoop(standardText: standardText, voiceIdentifier: nil, rate: 1.0, silenceNanoseconds: 300_000_000)
    }

    func startABABLoop(standardText: String, rate: Float, silenceNanoseconds: UInt64) async throws {
        try await startABABLoop(
            standardText: standardText,
            voiceIdentifier: nil,
            rate: rate,
            silenceNanoseconds: silenceNanoseconds
        )
    }
}

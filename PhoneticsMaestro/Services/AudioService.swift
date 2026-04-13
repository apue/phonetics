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
        try ensureIdle(for: "startRecording")

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
        try ensureIdle(for: "playStandard")
        transition(to: .playing(source: .standard))

        do {
            try await platformClient.playSpeech(text: text, voiceIdentifier: voiceIdentifier, rate: rate)
        } catch let error as AudioServiceError {
            transition(to: .idle)
            throw error
        } catch {
            transition(to: .idle)
            throw AudioServiceError.playbackFailed(error.localizedDescription)
        }

        transition(to: .idle)
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
        try await ensureIdleThenPlaySpeech(
            text: options[selectedIndex],
            source: .randomTest,
            attemptedAction: "playRandomTest",
            voiceIdentifier: voiceIdentifier,
            rate: rate
        )
        return selectedIndex
    }

    func playUserRecording(rate: Float = 1.0) async throws {
        try ensureIdle(for: "playUserRecording")
        let recordingURL = try await requireRecordingURL()
        transition(to: .playing(source: .userRecording))

        do {
            try await platformClient.playAudioFile(at: recordingURL, rate: rate)
        } catch let error as AudioServiceError {
            transition(to: .idle)
            throw error
        } catch {
            transition(to: .idle)
            throw AudioServiceError.playbackFailed(error.localizedDescription)
        }

        transition(to: .idle)
    }

    func startABABLoop(
        standardText: String,
        voiceIdentifier: String? = nil,
        rate: Float = 1.0,
        silenceNanoseconds: UInt64 = 300_000_000
    ) async throws {
        try ensureIdle(for: "startABABLoop")
        let recordingURL = try await requireRecordingURL()
        transition(to: .playingABAB)

        ababTask?.cancel()
        ababTask = Task {
            await runABABLoop(
                standardText: standardText,
                voiceIdentifier: voiceIdentifier,
                recordingURL: recordingURL,
                rate: rate,
                silenceNanoseconds: silenceNanoseconds
            )
        }
    }

    func stop() async {
        ababTask?.cancel()
        ababTask = nil
        await platformClient.stopPlayback()

        switch state {
        case .playing, .playingABAB:
            transition(to: .idle)
        case .idle, .recording:
            break
        }
    }

    private func ensureIdle(for action: String) throws {
        guard case .idle = state else {
            throw AudioServiceError.illegalTransition(currentState: state, attemptedAction: action)
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

    private func ensureIdleThenPlaySpeech(
        text: String,
        source: AudioPlaybackSource,
        attemptedAction: String,
        voiceIdentifier: String?,
        rate: Float
    ) async throws {
        try ensureIdle(for: attemptedAction)
        transition(to: .playing(source: source))

        do {
            try await platformClient.playSpeech(text: text, voiceIdentifier: voiceIdentifier, rate: rate)
        } catch let error as AudioServiceError {
            transition(to: .idle)
            throw error
        } catch {
            transition(to: .idle)
            throw AudioServiceError.playbackFailed(error.localizedDescription)
        }

        transition(to: .idle)
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
        standardText: String,
        voiceIdentifier: String?,
        recordingURL: URL,
        rate: Float,
        silenceNanoseconds: UInt64
    ) async {
        defer {
            ababTask = nil

            if case .playingABAB = state {
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

    func playUserRecording() async throws {
        try await playUserRecording(rate: 1.0)
    }

    func startABABLoop(standardText: String) async throws {
        try await startABABLoop(standardText: standardText, voiceIdentifier: nil, rate: 1.0, silenceNanoseconds: 300_000_000)
    }
}

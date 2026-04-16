import XCTest
@testable import PhoneticsCore

final class AudioServiceTests: XCTestCase {
    func testStartRecordingTransitionsToRecordingAndBuildsExpectedPath() async throws {
        let platform = MockAudioPlatformClient()
        let appSupportURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: appSupportURL) }

        let service = AudioService(
            platformClient: platform,
            fileManager: .default,
            appSupportURL: appSupportURL
        )

        let recordingURL = try await service.startRecording(
            itemType: "pair",
            itemID: 1,
            attempt: 1,
            sessionDate: "2026-04-13"
        )
        let currentState = await service.currentState()
        let startedRecordingURL = await platform.startedRecordingURL()

        XCTAssertEqual(recordingURL.lastPathComponent, "pair-1-attempt-1.caf")
        XCTAssertEqual(recordingURL.deletingLastPathComponent().lastPathComponent, "2026-04-13")
        XCTAssertEqual(currentState, .recording(recordingURL: recordingURL))
        XCTAssertEqual(startedRecordingURL, recordingURL)
    }

    func testPlayStandardWhileRecordingThrowsIllegalTransition() async throws {
        let platform = MockAudioPlatformClient()
        let appSupportURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: appSupportURL) }

        let service = AudioService(
            platformClient: platform,
            fileManager: .default,
            appSupportURL: appSupportURL
        )

        _ = try await service.startRecording(
            itemType: "pair",
            itemID: 1,
            attempt: 1,
            sessionDate: "2026-04-13"
        )

        do {
            try await service.playStandard(for: "but")
            XCTFail("Expected illegal transition error")
        } catch let error as AudioServiceError {
            guard case let .illegalTransition(currentState, attemptedAction) = error else {
                return XCTFail("Unexpected error: \(error)")
            }

            let startedRecordingURL = await platform.startedRecordingURL()
            let unwrappedRecordingURL = try XCTUnwrap(startedRecordingURL)
            XCTAssertEqual(currentState, .recording(recordingURL: unwrappedRecordingURL))
            XCTAssertEqual(attemptedAction, "playStandard")
        }
    }

    func testPlayRandomTestUsesInjectedSelectionAndReturnsToIdle() async throws {
        let platform = MockAudioPlatformClient(playbackMode: .controlled)
        let service = AudioService(
            platformClient: platform,
            randomIndex: { _ in 1 }
        )

        let playbackTask = Task {
            try await service.playRandomTest(options: ["but", "bat"])
        }

        await platform.waitUntilPlaybackStarts(count: 1)
        let currentStateWhilePlaying = await service.currentState()
        XCTAssertEqual(currentStateWhilePlaying, .playing(source: .randomTest))

        await platform.completePlayback()

        let selectedIndex = try await playbackTask.value
        let spokenTexts = await platform.spokenTexts()
        let finalState = await service.currentState()
        XCTAssertEqual(selectedIndex, 1)
        XCTAssertEqual(spokenTexts, ["bat"])
        XCTAssertEqual(finalState, .idle)
    }

    func testStartABABLoopRequiresExistingRecordingAndStopReturnsToIdle() async throws {
        let platform = MockAudioPlatformClient()
        let appSupportURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: appSupportURL) }

        let service = AudioService(
            platformClient: platform,
            fileManager: .default,
            appSupportURL: appSupportURL
        )

        _ = try await service.startRecording(
            itemType: "pair",
            itemID: 3,
            attempt: 1,
            sessionDate: "2026-04-13"
        )
        _ = try await service.stopRecording()

        try await service.startABABLoop(standardText: "luck", silenceNanoseconds: 1_000_000)
        let loopingState = await service.currentState()
        XCTAssertEqual(loopingState, .playing(source: .ababLoop))

        try await Task.sleep(nanoseconds: 5_000_000)
        await service.stop()

        let finalState = await service.currentState()
        let stopPlaybackCallCount = await platform.stopPlaybackCallCount()
        XCTAssertEqual(finalState, .idle)
        XCTAssertGreaterThanOrEqual(stopPlaybackCallCount, 1)
    }

    func testPlayStandardInterruptsCurrentPlaybackAndStartsNewSpeech() async throws {
        let platform = MockAudioPlatformClient(playbackMode: .controlled)
        let service = AudioService(
            platformClient: platform,
            randomIndex: { _ in 0 }
        )

        let firstPlayback = Task {
            try await service.playRandomTest(options: ["but", "bat"])
        }

        await platform.waitUntilPlaybackStarts(count: 1)

        let secondPlayback = Task {
            try await service.playStandard(for: "luck")
        }

        await platform.waitUntilPlaybackStarts(count: 2)
        await platform.completePlayback()

        _ = try await firstPlayback.value
        try await secondPlayback.value

        let spokenTexts = await platform.spokenTexts()
        let stopCount = await platform.stopPlaybackCallCount()
        let finalState = await service.currentState()
        XCTAssertEqual(spokenTexts, ["but", "luck"])
        XCTAssertGreaterThanOrEqual(stopCount, 1)
        XCTAssertEqual(finalState, .idle)
    }

    func testStartRecordingStopsPlaybackBeforeEnteringRecording() async throws {
        let platform = MockAudioPlatformClient(playbackMode: .controlled)
        let appSupportURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: appSupportURL) }

        let service = AudioService(
            platformClient: platform,
            fileManager: .default,
            appSupportURL: appSupportURL
        )

        let firstPlayback = Task {
            try await service.playStandard(for: "bat")
        }

        await platform.waitUntilPlaybackStarts(count: 1)
        let recordingURL = try await service.startRecording(
            itemType: "pair",
            itemID: 1,
            attempt: 1,
            sessionDate: "2026-04-16"
        )

        _ = try await firstPlayback.value
        let stopCount = await platform.stopPlaybackCallCount()
        let currentState = await service.currentState()

        XCTAssertEqual(stopCount, 1)
        XCTAssertEqual(currentState, .recording(recordingURL: recordingURL))
    }

    func testStartABABLoopInterruptsSinglePlayback() async throws {
        let platform = MockAudioPlatformClient(playbackMode: .controlled)
        let appSupportURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: appSupportURL) }

        let service = AudioService(
            platformClient: platform,
            fileManager: .default,
            appSupportURL: appSupportURL
        )

        _ = try await service.startRecording(
            itemType: "pair",
            itemID: 7,
            attempt: 1,
            sessionDate: "2026-04-16"
        )
        _ = try await service.stopRecording()

        let firstPlayback = Task {
            try await service.playStandard(for: "luck")
        }

        await platform.waitUntilPlaybackStarts(count: 1)
        try await service.startABABLoop(standardText: "lock", silenceNanoseconds: 1_000_000)

        _ = try await firstPlayback.value
        let currentState = await service.currentState()
        let stopCount = await platform.stopPlaybackCallCount()

        XCTAssertEqual(currentState, .playing(source: .ababLoop))
        XCTAssertGreaterThanOrEqual(stopCount, 1)
    }

    func testPlayUserRecordingInterruptsCurrentUserPlaybackAndRestarts() async throws {
        let platform = MockAudioPlatformClient(playbackMode: .controlled)
        let appSupportURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: appSupportURL) }

        let service = AudioService(
            platformClient: platform,
            fileManager: .default,
            appSupportURL: appSupportURL
        )

        _ = try await service.startRecording(
            itemType: "pair",
            itemID: 5,
            attempt: 1,
            sessionDate: "2026-04-14"
        )
        _ = try await service.stopRecording()

        let firstPlaybackTask = Task {
            try await service.playUserRecording()
        }

        await platform.waitUntilPlaybackStarts(count: 1)

        let secondPlaybackTask = Task {
            try await service.playUserRecording()
        }

        await platform.waitUntilPlaybackStarts(count: 2)

        await platform.completePlayback()
        try await firstPlaybackTask.value
        try await secondPlaybackTask.value

        let audioFilePlaybackCount = await platform.audioFilePlaybackCount()
        let finalState = await service.currentState()
        XCTAssertEqual(audioFilePlaybackCount, 2)
        XCTAssertEqual(finalState, .idle)
    }

    private func makeTemporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

actor MockAudioPlatformClient: AudioPlatformClient {
    enum PlaybackMode {
        case instant
        case controlled
    }

    private let playbackMode: PlaybackMode
    private var recordingURL: URL?
    private var fileURLs = Set<String>()
    private var speechTexts: [String] = []
    private var stopPlaybackCount = 0
    private var audioFilePlaybackCountValue = 0
    private var playbackStartCount = 0
    private var playbackContinuation: CheckedContinuation<Void, Error>?
    private var playbackStartedContinuation: CheckedContinuation<Void, Never>?

    init(playbackMode: PlaybackMode = .instant) {
        self.playbackMode = playbackMode
    }

    func requestRecordPermission() async -> Bool {
        true
    }

    func startRecording(to url: URL) async throws {
        recordingURL = url
    }

    func stopRecording() async throws {
        if let recordingURL {
            fileURLs.insert(recordingURL.path)
        }
    }

    func playSpeech(text: String, voiceIdentifier _: String?, rate _: Float) async throws {
        speechTexts.append(text)
        playbackStartCount += 1
        playbackStartedContinuation?.resume()
        playbackStartedContinuation = nil
        try await waitForPlaybackIfNeeded()
    }

    func playAudioFile(at url: URL, rate _: Float) async throws {
        audioFilePlaybackCountValue += 1
        fileURLs.insert(url.path)
        playbackStartCount += 1
        playbackStartedContinuation?.resume()
        playbackStartedContinuation = nil
        try await waitForPlaybackIfNeeded()
    }

    func stopPlayback() async {
        stopPlaybackCount += 1
        playbackContinuation?.resume()
        playbackContinuation = nil
    }

    func fileExists(at url: URL) async -> Bool {
        fileURLs.contains(url.path)
    }

    func startedRecordingURL() -> URL? {
        recordingURL
    }

    func spokenTexts() -> [String] {
        speechTexts
    }

    func stopPlaybackCallCount() -> Int {
        stopPlaybackCount
    }

    func audioFilePlaybackCount() -> Int {
        audioFilePlaybackCountValue
    }

    func waitUntilPlaybackStarts(count: Int) async {
        if playbackStartCount >= count {
            return
        }

        await withCheckedContinuation { continuation in
            playbackStartedContinuation = continuation
        }
    }

    func completePlayback() {
        playbackContinuation?.resume()
        playbackContinuation = nil
    }

    private func waitForPlaybackIfNeeded() async throws {
        guard playbackMode == .controlled else {
            return
        }

        try await withCheckedThrowingContinuation { continuation in
            playbackContinuation = continuation
        }
    }
}

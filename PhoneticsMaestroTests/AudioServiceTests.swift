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

        await platform.waitUntilPlaybackStarts()
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
        XCTAssertEqual(loopingState, .playingABAB)

        try await Task.sleep(nanoseconds: 5_000_000)
        await service.stop()

        let finalState = await service.currentState()
        let stopPlaybackCallCount = await platform.stopPlaybackCallCount()
        XCTAssertEqual(finalState, .idle)
        XCTAssertGreaterThanOrEqual(stopPlaybackCallCount, 1)
    }

    func testPlayUserRecordingWhileAlreadyPlayingDoesNotThrowIllegalTransition() async throws {
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

        await platform.waitUntilPlaybackStarts()

        do {
            try await service.playUserRecording()
        } catch {
            XCTFail("Expected re-entrant playUserRecording call to be ignored, got \(error)")
        }

        await platform.completePlayback()
        try await firstPlaybackTask.value

        let audioFilePlaybackCount = await platform.audioFilePlaybackCount()
        let finalState = await service.currentState()
        XCTAssertEqual(audioFilePlaybackCount, 1)
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
        playbackStartedContinuation?.resume()
        playbackStartedContinuation = nil
        try await waitForPlaybackIfNeeded()
    }

    func playAudioFile(at url: URL, rate _: Float) async throws {
        audioFilePlaybackCountValue += 1
        fileURLs.insert(url.path)
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

    func waitUntilPlaybackStarts() async {
        if !speechTexts.isEmpty {
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

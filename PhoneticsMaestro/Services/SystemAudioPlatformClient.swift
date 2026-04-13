import AVFoundation
import Foundation

actor SystemAudioPlatformClient: AudioPlatformClient {
    private let fileManager: FileManager
    private var recorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var speechContinuation: CheckedContinuation<Void, Error>?
    private var audioContinuation: CheckedContinuation<Void, Error>?
    private let speechDelegate = SpeechDelegate()
    private let audioDelegate = AudioDelegate()
    private var delegatesConfigured = false

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func requestRecordPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { allowed in
                    continuation.resume(returning: allowed)
                }
            }
        default:
            return false
        }
    }

    func startRecording(to url: URL) async throws {
        do {
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatAppleIMA4,
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1
            ]

            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.prepareToRecord()

            guard recorder.record() else {
                throw AudioServiceError.recordingFailed("AVAudioRecorder failed to start.")
            }

            self.recorder = recorder
        } catch let error as AudioServiceError {
            throw error
        } catch {
            throw AudioServiceError.recordingFailed(error.localizedDescription)
        }
    }

    func stopRecording() async throws {
        recorder?.stop()
        recorder = nil
    }

    func playSpeech(text: String, voiceIdentifier: String?, rate: Float) async throws {
        configureDelegatesIfNeeded()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voiceIdentifier.flatMap(AVSpeechSynthesisVoice.init(identifier:))
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * rate

        try await withCheckedThrowingContinuation { continuation in
            speechContinuation = continuation
            speechSynthesizer.speak(utterance)
        }
    }

    func playAudioFile(at url: URL, rate: Float) async throws {
        configureDelegatesIfNeeded()

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.enableRate = true
            player.rate = rate
            player.delegate = audioDelegate
            player.prepareToPlay()

            try await withCheckedThrowingContinuation { continuation in
                audioContinuation = continuation
                audioPlayer = player

                guard player.play() else {
                    continuation.resume(throwing: AudioServiceError.playbackFailed("AVAudioPlayer failed to start."))
                    audioContinuation = nil
                    audioPlayer = nil
                    return
                }
            }
        } catch let error as AudioServiceError {
            throw error
        } catch {
            throw AudioServiceError.playbackFailed(error.localizedDescription)
        }
    }

    func stopPlayback() async {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }

        if let audioPlayer {
            audioPlayer.stop()
            self.audioPlayer = nil
        }

        speechContinuation?.resume()
        speechContinuation = nil
        audioContinuation?.resume()
        audioContinuation = nil
    }

    func fileExists(at url: URL) async -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    private func configureDelegatesIfNeeded() {
        guard !delegatesConfigured else {
            return
        }

        speechDelegate.owner = self
        audioDelegate.owner = self
        speechSynthesizer.delegate = speechDelegate
        delegatesConfigured = true
    }

    private func finishSpeechPlayback() {
        speechContinuation?.resume()
        speechContinuation = nil
    }

    private func finishAudioPlayback(successfully _: Bool) {
        audioPlayer = nil
        audioContinuation?.resume()
        audioContinuation = nil
    }

    private final class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
        weak var owner: SystemAudioPlatformClient?

        func speechSynthesizer(
            _: AVSpeechSynthesizer,
            didFinish _: AVSpeechUtterance
        ) {
            let owner = owner
            Task {
                await owner?.finishSpeechPlayback()
            }
        }

        func speechSynthesizer(
            _: AVSpeechSynthesizer,
            didCancel _: AVSpeechUtterance
        ) {
            let owner = owner
            Task {
                await owner?.finishSpeechPlayback()
            }
        }
    }

    private final class AudioDelegate: NSObject, AVAudioPlayerDelegate, @unchecked Sendable {
        weak var owner: SystemAudioPlatformClient?

        func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            let owner = owner
            Task {
                await owner?.finishAudioPlayback(successfully: flag)
            }
        }

        func audioPlayerDecodeErrorDidOccur(_: AVAudioPlayer, error _: Error?) {
            let owner = owner
            Task {
                await owner?.finishAudioPlayback(successfully: false)
            }
        }
    }
}

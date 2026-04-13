import Foundation

protocol AudioPlatformClient: Sendable {
    func requestRecordPermission() async -> Bool
    func startRecording(to url: URL) async throws
    func stopRecording() async throws
    func playSpeech(text: String, voiceIdentifier: String?, rate: Float) async throws
    func playAudioFile(at url: URL, rate: Float) async throws
    func stopPlayback() async
    func fileExists(at url: URL) async -> Bool
}

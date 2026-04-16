import Foundation

protocol TrainingAudioServing: Sendable {
    func currentState() async -> AudioState
    func playRandomTest(options: [String]) async throws -> Int
    func playStandard(for text: String) async throws
    func playStandard(for text: String, rate: Float) async throws
    func startRecording(itemType: String, itemID: Int64, attempt: Int, sessionDate: String) async throws -> URL
    func stopRecording() async throws -> URL
    func playUserRecording() async throws
    func playUserRecording(rate: Float) async throws
    func startABABLoop(standardText: String) async throws
    func startABABLoop(standardText: String, rate: Float, silenceNanoseconds: UInt64) async throws
    func stop() async
}

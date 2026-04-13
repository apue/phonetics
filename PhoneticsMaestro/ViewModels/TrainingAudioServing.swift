import Foundation

protocol TrainingAudioServing: Sendable {
    func playRandomTest(options: [String]) async throws -> Int
    func playStandard(for text: String) async throws
    func startRecording(itemType: String, itemID: Int64, attempt: Int, sessionDate: String) async throws -> URL
    func stopRecording() async throws -> URL
    func playUserRecording() async throws
    func startABABLoop(standardText: String) async throws
    func stop() async
}

protocol TrainingAudioServing: Sendable {
    func playRandomTest(options: [String]) async throws -> Int
    func playStandard(for text: String) async throws
}

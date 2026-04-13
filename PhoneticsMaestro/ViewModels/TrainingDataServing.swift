protocol TrainingDataServing: Sendable {
    func fetchNextPair(afterID: Int64?) async throws -> PhonePair?
}

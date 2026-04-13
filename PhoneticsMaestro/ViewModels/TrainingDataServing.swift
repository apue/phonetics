protocol TrainingDataServing: Sendable {
    func fetchNextPair(afterID: Int64?) async throws -> PhonePair?
    func fetchPairTagState(for itemID: Int64) async throws -> TrainingTagState
    func updatePairTagState(for itemID: Int64, sessionDate: String, isSaved: Bool, isHard: Bool) async throws
}

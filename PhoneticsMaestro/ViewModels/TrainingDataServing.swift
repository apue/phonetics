protocol TrainingDataServing: Sendable {
    func fetchNextPair(afterID: Int64?) async throws -> PhonePair?
    func fetchPairTagState(for itemID: Int64) async throws -> TrainingTagState
    func fetchPairSessionStats(for itemID: Int64, sessionDate: String) async throws -> SessionStats
    func updatePairTagState(for itemID: Int64, sessionDate: String, isSaved: Bool, isHard: Bool) async throws
    func updatePairSessionStats(
        for itemID: Int64,
        sessionDate: String,
        stats: SessionStats,
        isSaved: Bool,
        isHard: Bool
    ) async throws
}

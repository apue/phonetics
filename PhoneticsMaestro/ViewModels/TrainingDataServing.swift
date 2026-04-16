protocol TrainingDataServing: Sendable {
    func fetchTrainingTargets() async throws -> [TrainingTargetSummary]
    func fetchTrainingCards(forTargetID targetID: String) async throws -> [TrainingCardItem]
    func fetchTagState(itemType: String, itemID: Int64) async throws -> TrainingTagState
    func fetchSessionStats(itemType: String, itemID: Int64, sessionDate: String) async throws -> SessionStats
    func updateTagState(itemType: String, itemID: Int64, sessionDate: String, isSaved: Bool, isHard: Bool) async throws
    func updateSessionStats(
        itemType: String,
        itemID: Int64,
        sessionDate: String,
        stats: SessionStats,
        isSaved: Bool,
        isHard: Bool
    ) async throws

    func fetchNextPair(afterID: Int64?) async throws -> PhonePair?
    func fetchPreviousPair(beforeID: Int64?) async throws -> PhonePair?
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

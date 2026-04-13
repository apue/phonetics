protocol HistoryDataServing: Sendable {
    func fetchHistorySessionSummaries() async throws -> [HistorySessionSummary]
}

import GRDB

struct HistorySessionSummary: Codable, Equatable, Sendable, Identifiable, FetchableRecord {
    var id: String { sessionDate }
    var sessionDate: String
    var totalListens: Int
    var totalCorrect: Int
    var totalPractices: Int
    var totalTimeSpentSec: Int
}

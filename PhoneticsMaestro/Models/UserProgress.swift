import GRDB

struct UserProgress: Codable, FetchableRecord, PersistableRecord, Sendable, Identifiable {
    var id: Int64?
    var itemType: String
    var itemID: Int64
    var sessionDate: String
    var listenCount: Int
    var correctCount: Int
    var wrongCount: Int
    var practiceCount: Int
    var timeSpentSec: Int
    var isSaved: Bool
    var isHard: Bool
    var createdAt: String
    var updatedAt: String
}

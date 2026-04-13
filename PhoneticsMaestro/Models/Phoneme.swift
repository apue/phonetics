import GRDB

struct Phoneme: Codable, FetchableRecord, PersistableRecord, Sendable, Identifiable {
    var id: Int64?
    var symbol: String
    var example: String?
    var description: String?
    var audioKey: String?
}

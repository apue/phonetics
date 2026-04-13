import GRDB

struct Sentence: Codable, FetchableRecord, PersistableRecord, Sendable, Identifiable {
    var id: Int64?
    var text: String
    var ipa: String?
    var phenomenon: String
    var notes: String?
    var tier: TrainingTier
}

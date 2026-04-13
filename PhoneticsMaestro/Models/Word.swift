import GRDB

struct Word: Codable, FetchableRecord, PersistableRecord, Sendable, Identifiable {
    var id: Int64?
    var text: String
    var ipa: String
    var phonemeID: Int64?
    var tier: TrainingTier
    var definition: String?
}

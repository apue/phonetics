import GRDB

struct PhonePair: Codable, FetchableRecord, Sendable, Identifiable, Equatable {
    let id: Int64
    let phonemeContrast: String
    let tier: TrainingTier
    let difficulty: Int
    let leftText: String
    let leftIPA: String
    let rightText: String
    let rightIPA: String
}

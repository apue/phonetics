struct SeedSentencePayload: Decodable, Sendable {
    let schema: String
    let version: String
    let sentences: [SentenceSeed]

    enum CodingKeys: String, CodingKey {
        case schema = "$schema"
        case version
        case sentences
    }

    struct SentenceSeed: Decodable, Sendable {
        let text: String
        let ipa: String
        let phenomenon: String
        let notes: String
    }
}

struct SeedPhonemePayload: Decodable, Sendable {
    let schema: String
    let version: String
    let phonemePairs: [PhonemePairSeed]

    enum CodingKeys: String, CodingKey {
        case schema = "$schema"
        case version
        case phonemePairs = "phoneme_pairs"
    }

    struct PhonemePairSeed: Decodable, Sendable {
        let contrast: String
        let phonemeA: PhonemeSeed
        let phonemeB: PhonemeSeed
        let wordPairs: [WordPairSeed]

        enum CodingKeys: String, CodingKey {
            case contrast
            case phonemeA = "phoneme_a"
            case phonemeB = "phoneme_b"
            case wordPairs = "word_pairs"
        }
    }

    struct PhonemeSeed: Decodable, Sendable {
        let symbol: String
        let example: String
        let description: String
    }

    struct WordPairSeed: Decodable, Sendable {
        let wordA: WordSeed
        let wordB: WordSeed
        let difficulty: Int

        enum CodingKeys: String, CodingKey {
            case wordA = "word_a"
            case wordB = "word_b"
            case difficulty
        }
    }

    struct WordSeed: Decodable, Sendable {
        let text: String
        let ipa: String
    }
}

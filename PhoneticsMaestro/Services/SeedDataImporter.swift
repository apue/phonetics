import Foundation
import GRDB

struct SeedDataImporter: DataImportService {
    private let bundle: Bundle

    init(bundle: Bundle = .module) {
        self.bundle = bundle
    }

    func importData(into db: Database) throws {
        let phonemePayload = try loadPhonemePayload()
        let sentencePayload = try loadSentencePayload()

        try insertPhonemePairs(from: phonemePayload, into: db)
        try insertSentences(from: sentencePayload, into: db)
    }

    private func loadPhonemePayload() throws -> SeedPhonemePayload {
        try decodeResource(named: "seed-phonemes", as: SeedPhonemePayload.self)
    }

    private func loadSentencePayload() throws -> SeedSentencePayload {
        try decodeResource(named: "seed-sentences", as: SeedSentencePayload.self)
    }

    private func decodeResource<T: Decodable>(named name: String, as type: T.Type) throws -> T {
        let resourceURL = try resourceURL(named: name)

        do {
            let data = try Data(contentsOf: resourceURL)
            return try JSONDecoder().decode(type, from: data)
        } catch let error as DecodingError {
            throw DataServiceError.invalidSeedData(error.localizedDescription)
        } catch {
            throw DataServiceError.invalidSeedData(error.localizedDescription)
        }
    }

    private func resourceURL(named name: String) throws -> URL {
        if let nestedURL = bundle.url(forResource: name, withExtension: "json", subdirectory: "SeedData") {
            return nestedURL
        }

        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw DataServiceError.missingResource("\(name).json")
        }

        return url
    }

    private func insertPhonemePairs(from payload: SeedPhonemePayload, into db: Database) throws {
        for contrast in payload.phonemePairs {
            let leftPhonemeID = try upsertPhoneme(contrast.phonemeA, into: db)
            let rightPhonemeID = try upsertPhoneme(contrast.phonemeB, into: db)

            for pair in contrast.wordPairs {
                let leftWordID = try insertWord(pair.wordA, phonemeID: leftPhonemeID, into: db)
                let rightWordID = try insertWord(pair.wordB, phonemeID: rightPhonemeID, into: db)

                try db.execute(
                    sql: """
                    INSERT INTO pairs (word_a_id, word_b_id, phoneme_contrast, tier, difficulty)
                    VALUES (?, ?, ?, ?, ?)
                    """,
                    arguments: [leftWordID, rightWordID, contrast.contrast, TrainingTier.word.rawValue, pair.difficulty]
                )
            }
        }
    }

    private func insertSentences(from payload: SeedSentencePayload, into db: Database) throws {
        for sentence in payload.sentences {
            try db.execute(
                sql: """
                INSERT INTO sentences (text, ipa, phenomenon, notes, tier)
                VALUES (?, ?, ?, ?, ?)
                """,
                arguments: [
                    sentence.text,
                    sentence.ipa,
                    sentence.phenomenon,
                    sentence.notes,
                    TrainingTier.sentence.rawValue
                ]
            )
        }
    }

    private func upsertPhoneme(_ phoneme: SeedPhonemePayload.PhonemeSeed, into db: Database) throws -> Int64 {
        try db.execute(
            sql: """
            INSERT OR IGNORE INTO phonemes (symbol, example, description, audio_key)
            VALUES (?, ?, ?, ?)
            """,
            arguments: [phoneme.symbol, phoneme.example, phoneme.description, phoneme.example]
        )

        guard let id = try Int64.fetchOne(
            db,
            sql: "SELECT id FROM phonemes WHERE symbol = ?",
            arguments: [phoneme.symbol]
        ) else {
            throw DataServiceError.invalidSeedData("Unable to load phoneme \(phoneme.symbol)")
        }

        return id
    }

    private func insertWord(
        _ word: SeedPhonemePayload.WordSeed,
        phonemeID: Int64,
        into db: Database
    ) throws -> Int64 {
        try db.execute(
            sql: """
            INSERT INTO words (text, ipa, phoneme_id, tier)
            VALUES (?, ?, ?, ?)
            """,
            arguments: [word.text, word.ipa, phonemeID, TrainingTier.word.rawValue]
        )

        return db.lastInsertedRowID
    }
}

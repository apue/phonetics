import Foundation
import GRDB

actor DataService {
    static let shared = DataService()

    private let appSupportURL: URL
    private let bundle: Bundle
    private let fileManager: FileManager
    private var databaseQueue: DatabaseQueue?
    private var isInitialized = false

    init(
        fileManager: FileManager = .default,
        bundle: Bundle = .module,
        appSupportURL: URL? = nil
    ) {
        self.fileManager = fileManager
        self.bundle = bundle
        self.appSupportURL = appSupportURL ?? AppPaths.applicationSupportDirectory(fileManager: fileManager)
    }

    func initialize() async throws {
        guard !isInitialized else {
            return
        }

        do {
            try createSupportDirectories()
            let queue = try openDatabase()
            try migrateDatabase(queue)
            try importSeedDataIfNeeded(using: queue)
            databaseQueue = queue
            isInitialized = true
        } catch let error as DataServiceError {
            throw error
        } catch {
            throw DataServiceError.database(error.localizedDescription)
        }
    }

    func currentDatabaseURL() -> URL {
        appSupportURL.appending(path: "maestro.sqlite")
    }

    func pairCount() throws -> Int {
        try withDatabase { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM pairs") ?? 0
        }
    }

    func sentenceCount() throws -> Int {
        try withDatabase { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sentences") ?? 0
        }
    }

    func fetchTrainingTargets() throws -> [TrainingTargetSummary] {
        try withDatabase { db in
            let pairs = try fetchAllPairs(in: db)
            let sentences = try fetchAllSentences(in: db)

            return buildTrainingTargets(pairs: pairs, sentences: sentences)
        }
    }

    func fetchTrainingCards(forTargetID targetID: String) throws -> [TrainingCardItem] {
        try withDatabase { db in
            let pairs = try fetchAllPairs(in: db)
            let sentences = try fetchAllSentences(in: db)

            if let contrast = pairContrast(from: targetID) {
                return pairs
                    .filter { $0.phonemeContrast == contrast }
                    .map { pair in
                        TrainingCardItem(
                            kind: .pair,
                            itemType: "pair",
                            itemID: pair.id,
                            targetID: targetID,
                            title: pair.tier == .phoneme ? "Phoneme Contrast" : "Word Contrast",
                            subtitle: "\(pair.leftText) / \(pair.rightText)",
                            leftText: pair.leftText,
                            leftIPA: pair.leftIPA,
                            rightText: pair.rightText,
                            rightIPA: pair.rightIPA,
                            tierLabel: tierLabel(for: pair.tier)
                        )
                    }
            }

            guard let phenomenon = sentencePhenomenon(from: targetID) else {
                return []
            }

            let groupedSentences = sentences.filter { $0.phenomenon == phenomenon }
            return buildSentenceTrainingCards(
                targetID: targetID,
                phenomenon: phenomenon,
                sentences: groupedSentences
            )
        }
    }

    func fetchTagState(itemType: String, itemID: Int64) throws -> TrainingTagState {
        try withDatabase { db in
            let row = try Row.fetchOne(
                db,
                sql: """
                SELECT is_saved, is_hard
                FROM user_progress
                WHERE item_type = ? AND item_id = ?
                ORDER BY updated_at DESC, id DESC
                LIMIT 1
                """,
                arguments: [itemType, itemID]
            )

            return TrainingTagState(
                isSaved: row?["is_saved"] ?? false,
                isHard: row?["is_hard"] ?? false
            )
        }
    }

    func fetchSessionStats(itemType: String, itemID: Int64, sessionDate: String) throws -> SessionStats {
        try withDatabase { db in
            let row = try Row.fetchOne(
                db,
                sql: """
                SELECT listen_count, correct_count, practice_count, time_spent_sec
                FROM user_progress
                WHERE item_type = ? AND item_id = ? AND session_date = ?
                ORDER BY updated_at DESC, id DESC
                LIMIT 1
                """,
                arguments: [itemType, itemID, sessionDate]
            )

            return SessionStats(
                listens: row?["listen_count"] ?? 0,
                correct: row?["correct_count"] ?? 0,
                practices: row?["practice_count"] ?? 0,
                elapsedSeconds: row?["time_spent_sec"] ?? 0
            )
        }
    }

    func fetchNextPair(afterID: Int64? = nil) throws -> PhonePair? {
        try withDatabase { db in
            if let afterID, let nextPair = try fetchPair(afterID: afterID, in: db) {
                return nextPair
            }

            return try fetchFirstPair(in: db)
        }
    }

    func fetchPreviousPair(beforeID: Int64? = nil) throws -> PhonePair? {
        try withDatabase { db in
            if let beforeID, let previousPair = try fetchPair(beforeID: beforeID, in: db) {
                return previousPair
            }

            return try fetchLastPair(in: db)
        }
    }

    func fetchPairTagState(for itemID: Int64) throws -> TrainingTagState {
        try fetchTagState(itemType: "pair", itemID: itemID)
    }

    func fetchPairSessionStats(for itemID: Int64, sessionDate: String) throws -> SessionStats {
        try fetchSessionStats(itemType: "pair", itemID: itemID, sessionDate: sessionDate)
    }

    func fetchHistorySessionSummaries() throws -> [HistorySessionSummary] {
        try withDatabase { db in
            try HistorySessionSummary.fetchAll(
                db,
                sql: """
                SELECT
                    session_date AS sessionDate,
                    SUM(listen_count) AS totalListens,
                    SUM(correct_count) AS totalCorrect,
                    SUM(practice_count) AS totalPractices,
                    SUM(time_spent_sec) AS totalTimeSpentSec
                FROM user_progress
                GROUP BY session_date
                ORDER BY session_date DESC
                """
            )
        }
    }

    func fetchSettings() throws -> AppSettings {
        try withDatabase { db in
            let row = try Row.fetchOne(
                db,
                sql: """
                SELECT
                    preferred_voice_name,
                    preferred_microphone_name,
                    abab_interval_ms,
                    has_dismissed_onboarding
                FROM app_settings
                WHERE id = 1
                """
            )

            return AppSettings(
                preferredVoiceName: row?["preferred_voice_name"] ?? "System Default",
                preferredMicrophoneName: row?["preferred_microphone_name"] ?? "System Default",
                ababIntervalMilliseconds: row?["abab_interval_ms"] ?? 300,
                hasDismissedOnboarding: (row?["has_dismissed_onboarding"] ?? 0) != 0
            )
        }
    }

    func updateSettings(_ settings: AppSettings) throws {
        try withDatabaseWrite { db in
            try db.execute(
                sql: """
                INSERT INTO app_settings (
                    id,
                    preferred_voice_name,
                    preferred_microphone_name,
                    abab_interval_ms,
                    has_dismissed_onboarding
                ) VALUES (1, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    preferred_voice_name = excluded.preferred_voice_name,
                    preferred_microphone_name = excluded.preferred_microphone_name,
                    abab_interval_ms = excluded.abab_interval_ms,
                    has_dismissed_onboarding = excluded.has_dismissed_onboarding
                """,
                arguments: [
                    settings.preferredVoiceName,
                    settings.preferredMicrophoneName,
                    settings.ababIntervalMilliseconds,
                    settings.hasDismissedOnboarding
                ]
            )
        }
    }

    func updatePairTagState(
        for itemID: Int64,
        sessionDate: String,
        isSaved: Bool,
        isHard: Bool
    ) throws {
        try updateTagState(
            itemType: "pair",
            itemID: itemID,
            sessionDate: sessionDate,
            isSaved: isSaved,
            isHard: isHard
        )
    }

    func updateTagState(
        itemType: String,
        itemID: Int64,
        sessionDate: String,
        isSaved: Bool,
        isHard: Bool
    ) throws {
        try withDatabaseWrite { db in
            if let progressID = try Int64.fetchOne(
                db,
                sql: """
                SELECT id
                FROM user_progress
                WHERE item_type = ? AND item_id = ? AND session_date = ?
                ORDER BY id DESC
                LIMIT 1
                """,
                arguments: [itemType, itemID, sessionDate]
            ) {
                try db.execute(
                    sql: """
                    UPDATE user_progress
                    SET is_saved = ?, is_hard = ?, updated_at = datetime('now')
                    WHERE id = ?
                    """,
                    arguments: [isSaved, isHard, progressID]
                )
            } else {
                try db.execute(
                    sql: """
                    INSERT INTO user_progress (
                        item_type,
                        item_id,
                        session_date,
                        is_saved,
                        is_hard
                    ) VALUES (?, ?, ?, ?, ?)
                    """,
                    arguments: [itemType, itemID, sessionDate, isSaved, isHard]
                )
            }
        }
    }

    func updatePairSessionStats(
        for itemID: Int64,
        sessionDate: String,
        stats: SessionStats,
        isSaved: Bool,
        isHard: Bool
    ) throws {
        try updateSessionStats(
            itemType: "pair",
            itemID: itemID,
            sessionDate: sessionDate,
            stats: stats,
            isSaved: isSaved,
            isHard: isHard
        )
    }

    func updateSessionStats(
        itemType: String,
        itemID: Int64,
        sessionDate: String,
        stats: SessionStats,
        isSaved: Bool,
        isHard: Bool
    ) throws {
        try withDatabaseWrite { db in
            if let progressID = try latestProgressID(
                itemType: itemType,
                for: itemID,
                sessionDate: sessionDate,
                in: db
            ) {
                try db.execute(
                    sql: """
                    UPDATE user_progress
                    SET
                        listen_count = ?,
                        correct_count = ?,
                        practice_count = ?,
                        time_spent_sec = ?,
                        is_saved = ?,
                        is_hard = ?,
                        updated_at = datetime('now')
                    WHERE id = ?
                    """,
                    arguments: [
                        stats.listens,
                        stats.correct,
                        stats.practices,
                        stats.elapsedSeconds,
                        isSaved,
                        isHard,
                        progressID
                    ]
                )
            } else {
                try db.execute(
                    sql: """
                    INSERT INTO user_progress (
                        item_type,
                        item_id,
                        session_date,
                        listen_count,
                        correct_count,
                        practice_count,
                        time_spent_sec,
                        is_saved,
                        is_hard
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    arguments: [
                        itemType,
                        itemID,
                        sessionDate,
                        stats.listens,
                        stats.correct,
                        stats.practices,
                        stats.elapsedSeconds,
                        isSaved,
                        isHard
                    ]
                )
            }
        }
    }

    private func createSupportDirectories() throws {
        do {
            try fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
            try fileManager.createDirectory(
                at: AppPaths.recordingsDirectory(appSupportURL: appSupportURL),
                withIntermediateDirectories: true
            )
        } catch {
            throw DataServiceError.fileSystem(error.localizedDescription)
        }
    }

    private func openDatabase() throws -> DatabaseQueue {
        do {
            return try DatabaseQueue(path: currentDatabaseURL().path)
        } catch {
            throw DataServiceError.database(error.localizedDescription)
        }
    }

    private func migrateDatabase(_ queue: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createSchema") { db in
            try db.create(table: "phonemes") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("symbol", .text).notNull().unique()
                table.column("example", .text)
                table.column("description", .text)
                table.column("audio_key", .text)
            }

            try db.create(table: "words") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("text", .text).notNull()
                table.column("ipa", .text).notNull()
                table.column("phoneme_id", .integer).references("phonemes", onDelete: .setNull)
                table.column("tier", .integer).notNull().defaults(to: 2)
                table.column("definition", .text)
            }

            try db.create(table: "pairs") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("word_a_id", .integer).notNull().references("words", onDelete: .cascade)
                table.column("word_b_id", .integer).notNull().references("words", onDelete: .cascade)
                table.column("phoneme_contrast", .text).notNull()
                table.column("tier", .integer).notNull().defaults(to: 2)
                table.column("difficulty", .integer).notNull().defaults(to: 1)
            }

            try db.create(table: "sentences") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("text", .text).notNull()
                table.column("ipa", .text)
                table.column("phenomenon", .text).notNull()
                table.column("notes", .text)
                table.column("tier", .integer).notNull().defaults(to: 3)
            }

            try db.create(table: "user_progress") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("item_type", .text).notNull()
                table.column("item_id", .integer).notNull()
                table.column("session_date", .text).notNull()
                table.column("listen_count", .integer).defaults(to: 0)
                table.column("correct_count", .integer).defaults(to: 0)
                table.column("wrong_count", .integer).defaults(to: 0)
                table.column("practice_count", .integer).defaults(to: 0)
                table.column("time_spent_sec", .integer).defaults(to: 0)
                table.column("is_saved", .integer).defaults(to: 0)
                table.column("is_hard", .integer).defaults(to: 0)
                table.column("created_at", .text).notNull().defaults(sql: "(datetime('now'))")
                table.column("updated_at", .text).notNull().defaults(sql: "(datetime('now'))")
            }

            try db.create(index: "idx_pairs_contrast", on: "pairs", columns: ["phoneme_contrast"])
            try db.create(index: "idx_progress_item", on: "user_progress", columns: ["item_type", "item_id"])
            try db.create(index: "idx_progress_date", on: "user_progress", columns: ["session_date"])
        }

        migrator.registerMigration("addAppSettings") { db in
            try db.create(table: "app_settings", ifNotExists: true) { table in
                table.column("id", .integer).primaryKey(onConflict: .replace)
                table.column("preferred_voice_name", .text).notNull().defaults(to: "System Default")
                table.column("preferred_microphone_name", .text).notNull().defaults(to: "System Default")
                table.column("abab_interval_ms", .integer).notNull().defaults(to: 300)
                table.column("has_dismissed_onboarding", .integer).notNull().defaults(to: 0)
            }
        }

        migrator.registerMigration("addOnboardingDismissal") { db in
            let hasOnboardingColumn = try Int.fetchOne(
                db,
                sql: """
                SELECT COUNT(*)
                FROM pragma_table_info('app_settings')
                WHERE name = 'has_dismissed_onboarding'
                """
            ) ?? 0

            guard hasOnboardingColumn == 0 else {
                return
            }

            try db.execute(
                sql: """
                ALTER TABLE app_settings
                ADD COLUMN has_dismissed_onboarding INTEGER NOT NULL DEFAULT 0
                """
            )
        }

        do {
            try migrator.migrate(queue)
        } catch {
            throw DataServiceError.database(error.localizedDescription)
        }
    }

    private func importSeedDataIfNeeded(using queue: DatabaseQueue) throws {
        let importer = SeedDataImporter(bundle: bundle)

        do {
            try queue.write { db in
                let existingPairs = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM pairs") ?? 0
                guard existingPairs == 0 else {
                    return
                }

                try importer.importData(into: db)
            }
        } catch let error as DataServiceError {
            throw error
        } catch {
            throw DataServiceError.database(error.localizedDescription)
        }
    }

    private func withDatabase<T>(_ operation: (Database) throws -> T) throws -> T {
        guard let databaseQueue else {
            throw DataServiceError.databaseUnavailable
        }

        do {
            return try databaseQueue.read(operation)
        } catch let error as DataServiceError {
            throw error
        } catch {
            throw DataServiceError.database(error.localizedDescription)
        }
    }

    private func withDatabaseWrite(_ operation: (Database) throws -> Void) throws {
        guard let databaseQueue else {
            throw DataServiceError.databaseUnavailable
        }

        do {
            try databaseQueue.write(operation)
        } catch let error as DataServiceError {
            throw error
        } catch {
            throw DataServiceError.database(error.localizedDescription)
        }
    }

    private func latestProgressID(
        itemType: String,
        for itemID: Int64,
        sessionDate: String,
        in db: Database
    ) throws -> Int64? {
        try Int64.fetchOne(
            db,
            sql: """
            SELECT id
            FROM user_progress
            WHERE item_type = ? AND item_id = ? AND session_date = ?
            ORDER BY id DESC
            LIMIT 1
            """,
            arguments: [itemType, itemID, sessionDate]
        )
    }

    private enum PairQueryOrder {
        case ascending
        case descending
    }

    private static let pairProjectionSQL = """
    SELECT
      pairs.id,
      pairs.phoneme_contrast AS phonemeContrast,
      pairs.tier,
      pairs.difficulty,
      wordA.text AS leftText,
      wordA.ipa AS leftIPA,
      wordB.text AS rightText,
      wordB.ipa AS rightIPA
    FROM pairs
    JOIN words AS wordA ON wordA.id = pairs.word_a_id
    JOIN words AS wordB ON wordB.id = pairs.word_b_id
    """

    private func pairQuerySQL(
        whereClause: String? = nil,
        order: PairQueryOrder,
        limit: Int? = 1
    ) -> String {
        var sql = Self.pairProjectionSQL

        if let whereClause {
            sql += "\nWHERE \(whereClause)"
        }

        switch order {
        case .ascending:
            sql += "\nORDER BY pairs.id"
        case .descending:
            sql += "\nORDER BY pairs.id DESC"
        }

        if let limit {
            sql += "\nLIMIT \(limit)"
        }

        return sql
    }

    private func fetchAllPairs(in db: Database) throws -> [PhonePair] {
        try PhonePair.fetchAll(
            db,
            sql: pairQuerySQL(order: .ascending, limit: nil)
        )
    }

    private func fetchAllSentences(in db: Database) throws -> [Sentence] {
        try Sentence.fetchAll(
            db,
            sql: """
            SELECT
              id,
              text,
              ipa,
              phenomenon,
              notes,
              tier
            FROM sentences
            ORDER BY id
            """
        )
    }

    private func buildTrainingTargets(
        pairs: [PhonePair],
        sentences: [Sentence]
    ) -> [TrainingTargetSummary] {
        let pairTargets = Dictionary(grouping: pairs, by: \.phonemeContrast)
            .sorted { lhs, rhs in
                (lhs.value.first?.id ?? 0) < (rhs.value.first?.id ?? 0)
            }
            .compactMap { entry -> TrainingTargetSummary? in
                let contrast = entry.key
                let items = entry.value
                guard let first = items.first else {
                    return nil
                }

                return TrainingTargetSummary(
                    id: "pair:\(contrast)",
                    group: .soundContrasts,
                    title: contrast,
                    subtitle: "\(first.leftText) / \(first.rightText)",
                    currentItemType: "pair"
                )
            }

        let sentenceTargets = Dictionary(grouping: sentences, by: \.phenomenon)
            .sorted { lhs, rhs in
                (lhs.value.first?.id ?? 0) < (rhs.value.first?.id ?? 0)
            }
            .compactMap { entry -> TrainingTargetSummary? in
                let phenomenon = entry.key
                let items = entry.value
                guard let first = items.first else {
                    return nil
                }

                return TrainingTargetSummary(
                    id: "sentence:\(phenomenon)",
                    group: sentenceGroup(for: phenomenon),
                    title: sentenceDisplayTitle(for: phenomenon),
                    subtitle: first.text,
                    currentItemType: "sentence"
                )
            }

        return pairTargets + sentenceTargets
    }

    private func pairContrast(from targetID: String) -> String? {
        guard targetID.hasPrefix("pair:") else {
            return nil
        }

        return String(targetID.dropFirst("pair:".count))
    }

    private func sentencePhenomenon(from targetID: String) -> String? {
        guard targetID.hasPrefix("sentence:") else {
            return nil
        }

        return String(targetID.dropFirst("sentence:".count))
    }

    private func sentenceGroup(for phenomenon: String) -> TrainingTargetGroup {
        switch phenomenon {
        case "stress", "intonation":
            .stressIntonation
        case "linking", "reduction", "elision":
            .linkingReduction
        default:
            .linkingReduction
        }
    }

    private func sentenceDisplayTitle(for phenomenon: String) -> String {
        switch phenomenon {
        case "linking":
            "Linking"
        case "reduction":
            "Reduction"
        case "elision":
            "Elision"
        case "stress":
            "Stress"
        case "intonation":
            "Intonation"
        default:
            phenomenon.capitalized
        }
    }

    func buildSentenceTrainingCards(
        targetID: String,
        phenomenon: String,
        sentences: [Sentence]
    ) -> [TrainingCardItem] {
        let sentencesWithIDs = sentences.compactMap { sentence -> (sentence: Sentence, id: Int64)? in
            guard let id = sentence.id else {
                return nil
            }

            return (sentence, id)
        }

        guard sentencesWithIDs.count >= 2 else {
            return []
        }

        return sentencesWithIDs.enumerated().map { index, entry in
            let comparison = sentencesWithIDs[(index + 1) % sentencesWithIDs.count]
            return TrainingCardItem(
                kind: .sentence(phenomenon: phenomenon),
                itemType: "sentence",
                itemID: entry.id,
                targetID: targetID,
                title: sentenceDisplayTitle(for: phenomenon),
                subtitle: entry.sentence.text,
                leftText: entry.sentence.text,
                leftIPA: entry.sentence.ipa,
                rightText: comparison.sentence.text,
                rightIPA: comparison.sentence.ipa,
                tierLabel: "Sentence"
            )
        }
    }

    private func tierLabel(for tier: TrainingTier) -> String {
        switch tier {
        case .phoneme:
            "Phoneme"
        case .word:
            "Word"
        case .sentence:
            "Sentence"
        }
    }

    private func fetchPair(afterID: Int64, in db: Database) throws -> PhonePair? {
        try PhonePair.fetchOne(
            db,
            sql: pairQuerySQL(whereClause: "pairs.id > ?", order: .ascending),
            arguments: [afterID]
        )
    }

    private func fetchPair(beforeID: Int64, in db: Database) throws -> PhonePair? {
        try PhonePair.fetchOne(
            db,
            sql: pairQuerySQL(whereClause: "pairs.id < ?", order: .descending),
            arguments: [beforeID]
        )
    }

    private func fetchFirstPair(in db: Database) throws -> PhonePair? {
        try PhonePair.fetchOne(
            db,
            sql: pairQuerySQL(order: .ascending)
        )
    }

    private func fetchLastPair(in db: Database) throws -> PhonePair? {
        try PhonePair.fetchOne(
            db,
            sql: pairQuerySQL(order: .descending)
        )
    }
}

extension DataService: TrainingDataServing {}
extension DataService: HistoryDataServing {}
extension DataService: SettingsDataServing {}

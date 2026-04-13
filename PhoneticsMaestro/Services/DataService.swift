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

    func fetchNextPair(afterID: Int64? = nil) throws -> PhonePair? {
        try withDatabase { db in
            if let afterID, let nextPair = try fetchPair(afterID: afterID, in: db) {
                return nextPair
            }

            return try fetchFirstPair(in: db)
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

    private func fetchPair(afterID: Int64, in db: Database) throws -> PhonePair? {
        try PhonePair.fetchOne(
            db,
            sql: """
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
            WHERE pairs.id > ?
            ORDER BY pairs.id
            LIMIT 1
            """,
            arguments: [afterID]
        )
    }

    private func fetchFirstPair(in db: Database) throws -> PhonePair? {
        try PhonePair.fetchOne(
            db,
            sql: """
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
            ORDER BY pairs.id
            LIMIT 1
            """
        )
    }
}

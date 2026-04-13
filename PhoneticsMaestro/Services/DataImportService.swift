import GRDB

protocol DataImportService {
    func importData(into db: Database) throws
}

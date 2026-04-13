import Foundation

enum DataServiceError: LocalizedError {
    case databaseUnavailable
    case database(String)
    case fileSystem(String)
    case invalidSeedData(String)
    case missingResource(String)

    var errorDescription: String? {
        switch self {
        case .databaseUnavailable:
            return "The database is not initialized yet."
        case let .database(message):
            return "Database error: \(message)"
        case let .fileSystem(message):
            return "File system error: \(message)"
        case let .invalidSeedData(message):
            return "Seed data error: \(message)"
        case let .missingResource(name):
            return "Missing bundled resource: \(name)"
        }
    }
}

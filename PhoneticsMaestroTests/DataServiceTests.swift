import XCTest
@testable import PhoneticsMaestro

final class DataServiceTests: XCTestCase {
    func testInitializeImportsSeedDataAndCreatesDatabase() async throws {
        let appSupportURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: appSupportURL) }

        let service = DataService(appSupportURL: appSupportURL)

        try await service.initialize()

        let databaseURL = await service.currentDatabaseURL()
        let pairCount = try await service.pairCount()
        let sentenceCount = try await service.sentenceCount()

        XCTAssertTrue(FileManager.default.fileExists(atPath: databaseURL.path))
        XCTAssertEqual(pairCount, 60)
        XCTAssertEqual(sentenceCount, 10)

        let firstPair = try await service.fetchNextPair()
        XCTAssertEqual(firstPair?.leftText, "but")
        XCTAssertEqual(firstPair?.rightText, "bat")
        XCTAssertEqual(firstPair?.phonemeContrast, "ʌ-æ")
    }

    func testFetchNextPairWrapsAroundWhenReachingTheEnd() async throws {
        let appSupportURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: appSupportURL) }

        let service = DataService(appSupportURL: appSupportURL)

        try await service.initialize()

        let wrappedPair = try await service.fetchNextPair(afterID: 10_000)
        XCTAssertEqual(wrappedPair?.leftText, "but")
        XCTAssertEqual(wrappedPair?.rightText, "bat")
    }

    private func makeTemporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

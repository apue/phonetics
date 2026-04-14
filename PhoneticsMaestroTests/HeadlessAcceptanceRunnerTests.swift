import XCTest
@testable import PhoneticsCore

final class HeadlessAcceptanceRunnerTests: XCTestCase {
    func testSeedCheckReportsNonZeroSeedCounts() async throws {
        let appSupportURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: appSupportURL) }

        let runner = HeadlessAcceptanceRunner(appSupportURL: appSupportURL)
        let result = await runner.run(.seedCheck)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.output.contains("status=ok"))
        XCTAssertGreaterThan(try value(for: "pair_count", in: result.output), 0)
        XCTAssertGreaterThan(try value(for: "sentence_count", in: result.output), 0)
    }

    func testDBSummaryIncludesCountsAndDatabasePath() async throws {
        let appSupportURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: appSupportURL) }

        let runner = HeadlessAcceptanceRunner(appSupportURL: appSupportURL)
        let result = await runner.run(.dbSummary)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.output.contains("status=ok"))
        XCTAssertTrue(result.output.contains("database_path="))
        XCTAssertTrue(result.output.contains(appSupportURL.appending(path: "maestro.sqlite").path))
        XCTAssertGreaterThan(try value(for: "pair_count", in: result.output), 0)
        XCTAssertGreaterThan(try value(for: "sentence_count", in: result.output), 0)
    }

    func testSmokeTestExercisesCoreQueries() async throws {
        let appSupportURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: appSupportURL) }

        let runner = HeadlessAcceptanceRunner(appSupportURL: appSupportURL)
        let result = await runner.run(.smokeTest)

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.output.contains("status=ok"))
        XCTAssertTrue(result.output.contains("pair_count="))
        XCTAssertTrue(result.output.contains("sentence_count="))
        XCTAssertTrue(result.output.contains("training_pair="))
        XCTAssertTrue(result.output.contains("history_summaries="))
        XCTAssertTrue(result.output.contains("settings="))
    }

    private func value(for key: String, in output: String) throws -> Int {
        let line = try XCTUnwrap(
            output
                .split(separator: "\n")
                .first { $0.hasPrefix("\(key)=") }
        )
        return Int(line.dropFirst(key.count + 1)) ?? -1
    }

    private func makeTemporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

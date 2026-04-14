import Foundation

public struct HeadlessAcceptanceRunResult: Sendable, Equatable {
    public let exitCode: Int32
    public let output: String

    public var succeeded: Bool {
        exitCode == 0
    }
}

public struct HeadlessAcceptanceRunner: Sendable {
    private let appSupportURL: URL?

    public init(appSupportURL: URL? = nil) {
        self.appSupportURL = appSupportURL
    }

    public func run(_ command: HeadlessAcceptanceCommand) async -> HeadlessAcceptanceRunResult {
        do {
            let service = DataService(appSupportURL: appSupportURL)
            try await service.initialize()
            let output = try await output(for: command, using: service)
            return HeadlessAcceptanceRunResult(exitCode: 0, output: output)
        } catch {
            return HeadlessAcceptanceRunResult(
                exitCode: 1,
                output: failureOutput(for: command, error: error)
            )
        }
    }

    private func output(
        for command: HeadlessAcceptanceCommand,
        using service: DataService
    ) async throws -> String {
        switch command {
        case .seedCheck:
            return try await seedCheckOutput(using: service)
        case .dbSummary:
            return try await databaseSummaryOutput(using: service)
        case .smokeTest:
            return try await smokeTestOutput(using: service)
        }
    }

    private func seedCheckOutput(using service: DataService) async throws -> String {
        let pairCount = try await countPairs(using: service)
        let sentenceCount = try await countSentences(using: service)

        guard pairCount > 0, sentenceCount > 0 else {
            throw HeadlessAcceptanceRunnerError.missingSeedData
        }

        return makeOutput(
            status: "ok",
            command: HeadlessAcceptanceCommand.seedCheck.rawValue,
            fields: [
                "pair_count": String(pairCount),
                "sentence_count": String(sentenceCount)
            ]
        )
    }

    private func databaseSummaryOutput(using service: DataService) async throws -> String {
        let pairCount = try await countPairs(using: service)
        let sentenceCount = try await countSentences(using: service)
        let databaseURL = await service.currentDatabaseURL()

        guard pairCount > 0, sentenceCount > 0 else {
            throw HeadlessAcceptanceRunnerError.missingSeedData
        }

        return makeOutput(
            status: "ok",
            command: HeadlessAcceptanceCommand.dbSummary.rawValue,
            fields: [
                "database_path": databaseURL.path,
                "pair_count": String(pairCount),
                "sentence_count": String(sentenceCount)
            ]
        )
    }

    private func smokeTestOutput(using service: DataService) async throws -> String {
        let pairCount = try await countPairs(using: service)
        let sentenceCount = try await countSentences(using: service)
        let pair = try await service.fetchNextPair()
        let histories = try await service.fetchHistorySessionSummaries()
        let settings = try await service.fetchSettings()

        guard let pair else {
            throw HeadlessAcceptanceRunnerError.missingTrainingPair
        }

        return makeOutput(
            status: "ok",
            command: HeadlessAcceptanceCommand.smokeTest.rawValue,
            fields: [
                "pair_count": String(pairCount),
                "sentence_count": String(sentenceCount),
                "training_pair": "\(pair.leftText)|\(pair.rightText)|\(pair.phonemeContrast)",
                "history_summaries": String(histories.count),
                "settings": [
                    settings.preferredVoiceName,
                    settings.preferredMicrophoneName,
                    String(settings.ababIntervalMilliseconds)
                ].joined(separator: "|")
            ]
        )
    }

    private func countPairs(using service: DataService) async throws -> Int {
        try await service.pairCount()
    }

    private func countSentences(using service: DataService) async throws -> Int {
        try await service.sentenceCount()
    }

    private func makeOutput(
        status: String,
        command: String,
        fields: [String: String]
    ) -> String {
        var lines = ["status=\(status)", "command=\(command)"]
        lines.append(contentsOf: fields.keys.sorted().map { "\($0)=\(fields[$0] ?? "")" })
        return lines.joined(separator: "\n") + "\n"
    }

    private func failureOutput(for command: HeadlessAcceptanceCommand, error: Error) -> String {
        makeOutput(
            status: "fail",
            command: command.rawValue,
            fields: [
                "error": String(describing: error)
            ]
        )
    }
}

private enum HeadlessAcceptanceRunnerError: Error {
    case missingSeedData
    case missingTrainingPair
}

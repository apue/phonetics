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
        case .uiScreenshots:
            return try await uiScreenshotOutput()
        case .uiReadout:
            return try await uiReadoutOutput()
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
        let histories = try await service.fetchHistorySessionSummaries()
        let settings = try await service.fetchSettings()

        guard pairCount > 0, sentenceCount > 0 else {
            throw HeadlessAcceptanceRunnerError.missingSeedData
        }

        return makeOutput(
            status: "ok",
            command: HeadlessAcceptanceCommand.dbSummary.rawValue,
            fields: [
                "database_path": databaseURL.path,
                "history_summaries": String(histories.count),
                "pair_count": String(pairCount),
                "settings": [
                    settings.preferredVoiceName,
                    settings.preferredMicrophoneName,
                    String(settings.ababIntervalMilliseconds)
                ].joined(separator: "|"),
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

    private func uiScreenshotOutput() async throws -> String {
        let baseDirectory = (appSupportURL ?? FileManager.default.temporaryDirectory)
            .appending(path: "ui-screenshots", directoryHint: .isDirectory)

        let rendered = try await MainActor.run {
            try UIScreenshotRenderer(outputDirectory: baseDirectory).render()
        }

        return makeOutput(
            status: "ok",
            command: HeadlessAcceptanceCommand.uiScreenshots.rawValue,
            fields: [
                "onboarding_png": rendered.onboarding.path,
                "training_png": rendered.training.path
            ]
        )
    }

    private func uiReadoutOutput() async throws -> String {
        let baseDirectory = (appSupportURL ?? FileManager.default.temporaryDirectory)
            .appending(path: "ui-screenshots", directoryHint: .isDirectory)

        let readout = try await MainActor.run {
            try UIScreenshotReadoutBuilder(outputDirectory: baseDirectory).build()
        }

        return makeOutput(
            status: "ok",
            command: HeadlessAcceptanceCommand.uiReadout.rawValue,
            fields: [
                "onboarding_markers": joined(readout.onboardingMarkers),
                "onboarding_sections": joined(readout.onboardingSections),
                "onboarding_text": readout.onboardingText,
                "training_markers": joined(readout.trainingMarkers),
                "training_sections": joined(readout.trainingSections),
                "training_text": readout.trainingText
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

    private func joined(_ values: [String]) -> String {
        values.joined(separator: "|")
    }

    private func failureOutput(for command: HeadlessAcceptanceCommand, error: Error) -> String {
        makeOutput(
            status: "fail",
            command: command.rawValue,
            fields: [
                "error_code": errorCode(for: error),
                "error_message": errorMessage(for: error)
            ]
        )
    }

    private func errorCode(for error: Error) -> String {
        switch error {
        case let dataServiceError as DataServiceError:
            switch dataServiceError {
            case .databaseUnavailable:
                return "database_unavailable"
            case .database:
                return "database_error"
            case .fileSystem:
                return "filesystem_error"
            case .invalidSeedData:
                return "invalid_seed_data"
            case .missingResource:
                return "missing_resource"
            }
        case let runnerError as HeadlessAcceptanceRunnerError:
            switch runnerError {
            case .missingSeedData:
                return "missing_seed_data"
            case .missingTrainingPair:
                return "missing_training_pair"
            }
        default:
            return "unknown_error"
        }
    }

    private func errorMessage(for error: Error) -> String {
        switch error {
        case let dataServiceError as DataServiceError:
            return dataServiceError.errorDescription ?? String(describing: dataServiceError)
        case let runnerError as HeadlessAcceptanceRunnerError:
            switch runnerError {
            case .missingSeedData:
                return "Seed counts are not available."
            case .missingTrainingPair:
                return "A training pair could not be loaded."
            }
        default:
            return String(describing: error)
        }
    }
}

private enum HeadlessAcceptanceRunnerError: Error {
    case missingSeedData
    case missingTrainingPair
}

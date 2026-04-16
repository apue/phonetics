public enum HeadlessAcceptanceCommand: String, Equatable, Sendable {
    case seedCheck = "seed-check"
    case dbSummary = "db-summary"
    case smokeTest = "smoke-test"
    case uiScreenshots = "ui-screenshots"
}

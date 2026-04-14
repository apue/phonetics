enum HeadlessAcceptanceCommand: Equatable {}

enum CLICommand: Equatable {
    case gui
    case headless(HeadlessAcceptanceCommand)
}

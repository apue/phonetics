import PhoneticsCore

enum CLICommand: Equatable {
    case gui
    case headless(HeadlessAcceptanceCommand)

    init?(arguments: [String]) {
        if arguments == ["--gui"] {
            self = .gui
            return
        }

        guard arguments.count == 2, arguments[0] == "--headless" else {
            return nil
        }

        guard let command = HeadlessAcceptanceCommand(rawValue: arguments[1]) else {
            return nil
        }

        self = .headless(command)
    }
}

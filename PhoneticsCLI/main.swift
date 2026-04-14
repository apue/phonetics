import Foundation
import PhoneticsCore

let arguments = Array(CommandLine.arguments.dropFirst())

guard let command = CLICommand(arguments: arguments) else {
    FileHandle.standardError.write(
        Data("Usage: phoneticsctl --gui | phoneticsctl --headless <command>\n".utf8)
    )
    exit(1)
}

switch command {
case .gui:
    do {
        let launcher = AppLauncher()
        let command = try launcher.guiLaunchCommand()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command[0])
        process.arguments = Array(command.dropFirst())
        try process.run()
        process.waitUntilExit()
        exit(process.terminationStatus)
    } catch {
        FileHandle.standardError.write(Data("\(error)\n".utf8))
        exit(1)
    }
case let .headless(headlessCommand):
    let runner = HeadlessAcceptanceRunner()
    let result = await runner.run(headlessCommand)
    FileHandle.standardOutput.write(Data(result.output.utf8))
    exit(result.exitCode)
}

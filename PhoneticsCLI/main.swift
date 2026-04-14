import Foundation
import PhoneticsCore

let arguments = Array(CommandLine.arguments.dropFirst())

switch arguments {
case ["--gui"]:
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
default:
    FileHandle.standardError.write(
        Data("Usage: phoneticsctl --gui | phoneticsctl --headless <command>\n".utf8)
    )
    exit(1)
}

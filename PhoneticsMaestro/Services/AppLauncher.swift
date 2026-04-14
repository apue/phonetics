import Foundation

public enum AppLauncherError: Error, Equatable {
    case bundlePathNotConfigured
}

public struct AppLauncher {
    let appPathProvider: @Sendable () throws -> String

    public init(
        appPathProvider: @escaping @Sendable () throws -> String = {
            if let override = ProcessInfo.processInfo.environment["PHONETICS_APP_BUNDLE_PATH"] {
                return override
            }

            let fallback = FileManager.default.currentDirectoryPath
                + "/DerivedData/Build/Products/Debug/PhoneticsMaestro.app"
            if FileManager.default.fileExists(atPath: fallback) {
                return fallback
            }

            throw AppLauncherError.bundlePathNotConfigured
        }
        ) {
        self.appPathProvider = appPathProvider
    }

    public func guiLaunchCommand() throws -> [String] {
        ["/usr/bin/open", try appPathProvider()]
    }
}

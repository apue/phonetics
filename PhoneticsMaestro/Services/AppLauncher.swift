import Foundation

public enum AppLauncherError: Error, Equatable {
    case bundlePathNotConfigured
}

public struct AppLauncher {
    let appPathProvider: () throws -> String

    public init(
        appPathProvider: (() throws -> String)? = nil
    ) {
        if let appPathProvider {
            self.appPathProvider = appPathProvider
        } else {
            self.appPathProvider = {
                try AppLauncher.resolveBundlePath(
                    fileManager: .default,
                    currentDirectoryPath: FileManager.default.currentDirectoryPath,
                    homeDirectoryPath: FileManager.default.homeDirectoryForCurrentUser.path,
                    environment: ProcessInfo.processInfo.environment
                )
            }
        }
    }

    public func guiLaunchCommand() throws -> [String] {
        ["/usr/bin/open", try appPathProvider()]
    }

    init(
        fileManager: FileManager,
        currentDirectoryPath: String,
        homeDirectoryPath: String,
        environment: [String: String]
    ) {
        self.appPathProvider = {
            try Self.resolveBundlePath(
                fileManager: fileManager,
                currentDirectoryPath: currentDirectoryPath,
                homeDirectoryPath: homeDirectoryPath,
                environment: environment
            )
        }
    }

    static func resolveBundlePath(
        fileManager: FileManager,
        currentDirectoryPath: String,
        homeDirectoryPath: String,
        environment: [String: String]
    ) throws -> String {
        if let override = environment["PHONETICS_APP_BUNDLE_PATH"] {
            return override
        }

        let repoLocalFallback = currentDirectoryPath
            + "/DerivedData/Build/Products/Debug/PhoneticsMaestro.app"
        if fileManager.fileExists(atPath: repoLocalFallback) {
            return repoLocalFallback
        }

        if let derivedDataFallback = latestDerivedDataBundlePath(
            fileManager: fileManager,
            homeDirectoryPath: homeDirectoryPath
        ) {
            return derivedDataFallback
        }

        throw AppLauncherError.bundlePathNotConfigured
    }

    private static func latestDerivedDataBundlePath(
        fileManager: FileManager,
        homeDirectoryPath: String
    ) -> String? {
        let derivedDataRoot = homeDirectoryPath
            + "/Library/Developer/Xcode/DerivedData"

        guard let projectDirectories = try? fileManager.contentsOfDirectory(
            atPath: derivedDataRoot
        ) else {
            return nil
        }

        let candidates = projectDirectories.compactMap { projectDirectory -> Candidate? in
            let bundlePath = derivedDataRoot
                + "/\(projectDirectory)/Build/Products/Debug/PhoneticsMaestro.app"

            guard fileManager.fileExists(atPath: bundlePath) else {
                return nil
            }

            let attributes = try? fileManager.attributesOfItem(atPath: bundlePath)
            let modificationDate = attributes?[.modificationDate] as? Date ?? .distantPast
            return Candidate(path: bundlePath, modificationDate: modificationDate)
        }

        return candidates.sorted { lhs, rhs in
            if lhs.modificationDate != rhs.modificationDate {
                return lhs.modificationDate > rhs.modificationDate
            }
            return lhs.path < rhs.path
        }.first?.path
    }
}

private struct Candidate {
    let path: String
    let modificationDate: Date
}

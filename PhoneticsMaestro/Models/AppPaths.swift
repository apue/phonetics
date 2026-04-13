import Foundation

enum AppPaths {
    static func applicationSupportDirectory(fileManager: FileManager) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return baseURL.appending(path: "PhoneticsMaestro", directoryHint: .isDirectory)
    }

    static func recordingsDirectory(appSupportURL: URL) -> URL {
        appSupportURL.appending(path: "recordings", directoryHint: .isDirectory)
    }
}

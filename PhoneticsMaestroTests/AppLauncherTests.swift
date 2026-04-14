import XCTest
@testable import PhoneticsCore

final class AppLauncherTests: XCTestCase {
    func testGUICommandBuildsOpenArgumentsForAppBundle() {
        let launcher = AppLauncher(appPathProvider: { "/tmp/PhoneticsMaestro.app" })

        XCTAssertEqual(
            try launcher.guiLaunchCommand(),
            ["/usr/bin/open", "/tmp/PhoneticsMaestro.app"]
        )
    }

    func testDefaultResolverUsesEnvironmentOverrideFirst() throws {
        let launcher = makeLauncher(
            environment: ["PHONETICS_APP_BUNDLE_PATH": "/tmp/env/PhoneticsMaestro.app"],
            currentDirectoryPath: makeTemporaryDirectory().path,
            homeDirectoryPath: makeTemporaryDirectory().path
        )

        XCTAssertEqual(try launcher.guiLaunchCommand(), ["/usr/bin/open", "/tmp/env/PhoneticsMaestro.app"])
    }

    func testDefaultResolverUsesRepoLocalFallbackSecond() throws {
        let repoRoot = makeTemporaryDirectory()
        let derivedDataRoot = makeTemporaryDirectory()
        let repoLocalBundle = repoRoot.appending(path: "DerivedData/Build/Products/Debug/PhoneticsMaestro.app")
        try FileManager.default.createDirectory(at: repoLocalBundle, withIntermediateDirectories: true)

        let launcher = makeLauncher(
            currentDirectoryPath: repoRoot.path,
            homeDirectoryPath: derivedDataRoot.path
        )

        XCTAssertEqual(try launcher.guiLaunchCommand(), ["/usr/bin/open", repoLocalBundle.path])
    }

    func testDefaultResolverUsesDerivedDataFallbackThird() throws {
        let repoRoot = makeTemporaryDirectory()
        let homeDirectory = makeTemporaryDirectory()
        let derivedDataRoot = homeDirectory.appending(path: "Library/Developer/Xcode/DerivedData")
        let olderDerivedData = derivedDataRoot.appending(path: "Old-abc123/Build/Products/Debug/PhoneticsMaestro.app")
        let newerDerivedData = derivedDataRoot.appending(path: "New-def456/Build/Products/Debug/PhoneticsMaestro.app")

        try FileManager.default.createDirectory(at: olderDerivedData, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: newerDerivedData, withIntermediateDirectories: true)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 1_000)],
            ofItemAtPath: olderDerivedData.path
        )
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 2_000)],
            ofItemAtPath: newerDerivedData.path
        )

        let launcher = makeLauncher(
            currentDirectoryPath: repoRoot.path,
            homeDirectoryPath: homeDirectory.path
        )

        XCTAssertEqual(try launcher.guiLaunchCommand(), ["/usr/bin/open", newerDerivedData.path])
    }

    func testDefaultResolverThrowsWhenNoBundleCanBeFound() {
        let launcher = makeLauncher(
            currentDirectoryPath: makeTemporaryDirectory().path,
            homeDirectoryPath: makeTemporaryDirectory().path
        )

        XCTAssertThrowsError(try launcher.guiLaunchCommand()) { error in
            XCTAssertEqual(error as? AppLauncherError, .bundlePathNotConfigured)
        }
    }

    private func makeLauncher(
        environment: [String: String] = [:],
        currentDirectoryPath: String,
        homeDirectoryPath: String
    ) -> AppLauncher {
        AppLauncher(
            fileManager: FileManager.default,
            currentDirectoryPath: currentDirectoryPath,
            homeDirectoryPath: homeDirectoryPath,
            environment: environment
        )
    }

    private func makeTemporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

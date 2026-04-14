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
}

import SwiftUI
import XCTest
@testable import PhoneticsMaestro

@MainActor
final class AppViewModelTests: XCTestCase {
    func testToggleSidebarUpdatesCollapsedState() {
        let viewModel = AppViewModel()

        XCTAssertEqual(viewModel.splitViewVisibility, .all)
        XCTAssertFalse(viewModel.isSidebarCollapsed)

        viewModel.toggleSidebar()
        XCTAssertEqual(viewModel.splitViewVisibility, .detailOnly)
        XCTAssertTrue(viewModel.isSidebarCollapsed)

        viewModel.toggleSidebar()
        XCTAssertEqual(viewModel.splitViewVisibility, .all)
        XCTAssertFalse(viewModel.isSidebarCollapsed)
    }
}

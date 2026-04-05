import XCTest
@testable import ActivityMonitorDashboard

final class AppVisibilityPreferencesTests: XCTestCase {
    func testNormalizationKeepsMenuBarAccessWhenBothIconsWouldBeHidden() {
        let preferences = AppVisibilityPreferences(
            showsMenuBarIcon: false,
            showsDockIcon: false
        )
        .normalized

        XCTAssertTrue(preferences.showsMenuBarIcon)
        XCTAssertFalse(preferences.showsDockIcon)
    }

    func testActivationPolicyUsesAccessoryModeWhenDockIconIsHidden() {
        let preferences = AppVisibilityPreferences(
            showsMenuBarIcon: true,
            showsDockIcon: false
        )

        XCTAssertEqual(preferences.activationPolicy, .accessory)
    }

    func testAppKeepsRunningWhenAnyLaunchSurfaceRemainsVisible() {
        let menuBarOnly = AppVisibilityPreferences(
            showsMenuBarIcon: true,
            showsDockIcon: false
        )
        let dockOnly = AppVisibilityPreferences(
            showsMenuBarIcon: false,
            showsDockIcon: true
        )

        XCTAssertTrue(menuBarOnly.shouldStayRunningAfterLastWindowCloses)
        XCTAssertTrue(dockOnly.shouldStayRunningAfterLastWindowCloses)
    }
}

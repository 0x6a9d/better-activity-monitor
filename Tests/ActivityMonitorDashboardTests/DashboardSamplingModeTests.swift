import XCTest
@testable import ActivityMonitorDashboard

final class DashboardSamplingModeTests: XCTestCase {
    func testForegroundSamplingModeUsesFastestRefreshIntervals() {
        XCTAssertEqual(DashboardViewModel.SamplingMode.foreground.refreshInterval, .seconds(2))
        XCTAssertEqual(DashboardViewModel.SamplingMode.foreground.cpuMemoryLeaderRefreshInterval, 30)
        XCTAssertEqual(DashboardViewModel.SamplingMode.foreground.gpuLeaderRefreshInterval, 20)
    }

    func testBackgroundSamplingModeKeepsSamplingAtReducedCadence() {
        XCTAssertEqual(DashboardViewModel.SamplingMode.background.refreshInterval, .seconds(6))
        XCTAssertEqual(DashboardViewModel.SamplingMode.background.cpuMemoryLeaderRefreshInterval, 120)
        XCTAssertEqual(DashboardViewModel.SamplingMode.background.gpuLeaderRefreshInterval, 90)
    }

    func testPausedSamplingModeDisablesAllSampling() {
        XCTAssertNil(DashboardViewModel.SamplingMode.paused.refreshInterval)
        XCTAssertNil(DashboardViewModel.SamplingMode.paused.cpuMemoryLeaderRefreshInterval)
        XCTAssertNil(DashboardViewModel.SamplingMode.paused.gpuLeaderRefreshInterval)
    }
}

import Testing
@testable import ActivityMonitorDashboard

@Test
func dashboardLayoutMetricsKeepsDefaultGraphHeightWhenSpaceIsAvailable() {
    let height = DashboardLayoutMetrics.graphHeight(forContentHeight: 1012, rowCount: 4)

    #expect(height == DashboardLayoutMetrics.defaultGraphHeight)
}

@Test
func dashboardLayoutMetricsShrinksGraphHeightForShorterWindows() {
    let height = DashboardLayoutMetrics.graphHeight(forContentHeight: 900, rowCount: 4)

    #expect(height < DashboardLayoutMetrics.defaultGraphHeight)
    #expect(height > DashboardLayoutMetrics.minimumGraphHeight)
    #expect(height < 80)
}

@Test
func dashboardLayoutMetricsStopsShrinkingAtMinimumGraphHeight() {
    let height = DashboardLayoutMetrics.graphHeight(forContentHeight: 856, rowCount: 4)

    #expect(height == DashboardLayoutMetrics.minimumGraphHeight)
}

@Test
func dashboardLayoutMetricsMaximumContentHeightMatchesFourDashboardRows() {
    let height = DashboardLayoutMetrics.maximumContentHeight(forRowCount: 4)

    #expect(height == 1012)
}

@Test
func dashboardLayoutMetricsMinimumResizableContentHeightMatchesFourDashboardRows() {
    let height = DashboardLayoutMetrics.minimumResizableContentHeight(forRowCount: 4)

    #expect(height == 868)
}

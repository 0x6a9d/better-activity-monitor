import Testing
@testable import ActivityMonitorDashboard

@MainActor
@Test
func wattsAndGigahertzFormattingStayStableAcrossCachedFormatterReuse() {
    #expect(MetricFormatting.watts(12.34) == "12.3 W")
    #expect(MetricFormatting.watts(12.34, minimumFractionDigits: 2, maximumFractionDigits: 2, includeSpace: false) == "12.34W")
    #expect(MetricFormatting.gigahertz(3.19) == "3.2GHz")
    #expect(MetricFormatting.gigahertz(3.19, fractionDigits: 2) == "3.19GHz")
}

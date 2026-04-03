import Testing
@testable import ActivityMonitorDashboardCore

@Test
func pressureLevelUsesExpectedThresholds() {
    #expect(PressureLevel(normalizedValue: 0.40) == .good)
    #expect(PressureLevel(normalizedValue: 0.65) == .moderate)
    #expect(PressureLevel(normalizedValue: 0.90) == .heavy)
}

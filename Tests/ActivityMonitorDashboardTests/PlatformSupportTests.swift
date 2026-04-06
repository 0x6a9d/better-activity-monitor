import Testing
@testable import ActivityMonitorDashboard

@Test
func platformSupportRequiresAppleSiliconFlag() {
    #expect(PlatformSupport.isAppleSiliconHardware(arm64Flag: 1))
    #expect(!PlatformSupport.isAppleSiliconHardware(arm64Flag: 0))
    #expect(!PlatformSupport.isAppleSiliconHardware(arm64Flag: nil))
}

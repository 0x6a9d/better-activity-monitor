import Foundation
import Testing
@testable import ActivityMonitorDashboard

@Test
func systemHardwareProfileParsesChipCoreCountsAndMemoryDetails() {
    let json = """
    {
      "SPDisplaysDataType": [
        {
          "sppci_cores": "40",
          "sppci_model": "Apple M5 Max"
        }
      ],
      "SPHardwareDataType": [
        {
          "chip_type": "Apple M5 Max",
          "number_processors": "proc 18:6:0:12",
          "physical_memory": "64 GB"
        }
      ]
    }
    """

    let profile = SystemHardwareProfileLoader.parse(data: Data(json.utf8))

    #expect(profile?.chipDisplayName == "Apple M5 Max")
    #expect(profile?.cpuLoadTitleDetail == "18 Cores")
    #expect(profile?.cpuFrequencyTitleDetail == "12P / 6S")
    #expect(profile?.gpuPressureTitleDetail == "40 Cores")
    #expect(profile?.memoryPressureTitleDetail == "64 GB")
}

@Test
func systemHardwareProfileFormatsBaseChipCpuTierSummary() {
    let json = """
    {
      "SPDisplaysDataType": [],
      "SPHardwareDataType": [
        {
          "chip_type": "Apple M5",
          "number_processors": "proc 10:4:6:0",
          "physical_memory": "24 GB"
        }
      ]
    }
    """

    let profile = SystemHardwareProfileLoader.parse(data: Data(json.utf8))

    #expect(profile?.cpuFrequencyTitleDetail == "6E / 4P")
}

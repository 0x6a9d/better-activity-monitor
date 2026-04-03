import Testing
@testable import ActivityMonitorDashboardCore

@Test
func memoryMetricDisplayUsesReadableMBAndGBUnits() {
    #expect(ProcessLeaderSampler.formattedMemoryMetricDisplay("4298M") == "4.3 GB")
    #expect(ProcessLeaderSampler.formattedMemoryMetricDisplay("788.4M") == "788.4 MB")
    #expect(ProcessLeaderSampler.formattedMemoryMetricDisplay("9.91G") == "9.9 GB")
}

@Test
func gpuRegistryParserCollectsPerProcessTotalsAndLastSubmissionPID() {
    let sample = """
    +-o AGXAcceleratorG17X  <class AGXAcceleratorG17X>
      | {
      |   "AGCInfo" = {"fLastSubmissionPID"=4242,"fSubmissionsSinceLastCheck"=3}
      | }
      |
      +-o AGXDeviceUserClient  <class AGXDeviceUserClient>
      |   {
      |     "AppUsage" = ({"API"="Metal","lastSubmittedTime"=1000,"accumulatedGPUTime"=250000000},{"API"="Metal","lastSubmittedTime"=900,"accumulatedGPUTime"=50000000})
      |     "IOUserClientCreator" = "pid 4242, wine64-preloader"
      |   }
      |
      +-o AGXDeviceUserClient  <class AGXDeviceUserClient>
          {
            "AppUsage" = ({"API"="Metal","lastSubmittedTime"=800,"accumulatedGPUTime"=125000000})
            "IOUserClientCreator" = "pid 808, Brave Browser"
          }
    """

    let snapshot = ProcessLeaderSampler.parseGPURegistrySnapshot(from: sample)

    #expect(snapshot.lastSubmittedPID == 4242)
    #expect(snapshot.processes.count == 2)
    #expect(snapshot.processes[4242]?.name == "wine64-preloader")
    #expect(snapshot.processes[4242]?.total == 300_000_000)
    #expect(snapshot.processes[4242]?.lastSubmittedTime == 1000)
    #expect(snapshot.processes[4242]?.activeUsageEntryCount == 2)
    #expect(snapshot.processes[808]?.name == "Brave Browser")
    #expect(snapshot.processes[808]?.total == 125_000_000)
}

import Testing
@testable import ActivityMonitorDashboardCore

@Test
func memoryMetricDisplayUsesReadableMBAndGBUnits() {
    #expect(ProcessLeaderSampler.formattedMemoryMetricDisplay("4298M") == "4.3 GB")
    #expect(ProcessLeaderSampler.formattedMemoryMetricDisplay("788.4M") == "788.4 MB")
    #expect(ProcessLeaderSampler.formattedMemoryMetricDisplay("9.91G") == "9.9 GB")
}

@Test
func processSnapshotParserExtractsPidCpuMemoryAndCommand() {
    let sample = """
       101   12.5    2048 /Applications/Foo App.app/Contents/MacOS/Foo App
       202    0.0  512000 /System/Library/CoreServices/Finder.app/Contents/MacOS/Finder
    """

    let rows = ProcessLeaderSampler.parseProcessSnapshot(from: sample)

    #expect(rows.count == 2)
    #expect(rows[0].pid == 101)
    #expect(rows[0].cpuPercent == 12.5)
    #expect(rows[0].residentKilobytes == 2_048)
    #expect(rows[0].command == "Foo App")
    #expect(rows[1].command == "Finder")
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

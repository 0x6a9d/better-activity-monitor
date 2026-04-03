import Testing
@testable import ActivityMonitorDashboardCore

@Test
func systemMetricsSamplerProducesNonNegativeSamples() {
    let sampler = SystemMetricsSampler()
    let snapshot = sampler.sample()

    #expect(snapshot.cpu.totalUsage >= 0)
    #expect(snapshot.cpuFrequency.performanceGHz >= 0)
    #expect(snapshot.cpuFrequency.superGHz >= 0)
    #expect(snapshot.memory.pressure >= 0)
    #expect(snapshot.gpu.utilization >= 0)
    #expect(snapshot.ane.utilization >= 0)
    #expect(snapshot.thermal.fanCount >= 0)

    if let cpuPower = snapshot.cpu.powerWatts {
        #expect(cpuPower >= 0)
    }

    if let memoryPower = snapshot.memory.powerWatts {
        #expect(memoryPower >= 0)
    }

    if let gpuPower = snapshot.gpu.powerWatts {
        #expect(gpuPower >= 0)
    }

    if let totalPower = snapshot.totalPower {
        #expect(totalPower.watts >= 0)
    }

    if let fanPercent = snapshot.thermal.fanSpeedPercent {
        #expect(fanPercent >= 0)
    }

    if let cpuTemperature = snapshot.thermal.cpuTemperatureCelsius {
        #expect(cpuTemperature >= 0)
    }

    if let gpuTemperature = snapshot.thermal.gpuTemperatureCelsius {
        #expect(gpuTemperature >= 0)
    }
}

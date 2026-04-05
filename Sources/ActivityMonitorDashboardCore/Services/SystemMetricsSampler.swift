import Foundation

public final class SystemMetricsSampler {
    private static let cpuFrequencyRefreshInterval: TimeInterval = 6
    private static let thermalRefreshInterval: TimeInterval = 10

    private let cpuSampler = CPUSampler()
    private let cpuFrequencySampler = CPUFrequencySampler()
    private let memorySampler = MemorySampler()
    private let gpuSampler = GPUSampler()
    private let aneSampler = ANESampler()
    private let thermalSampler = ThermalSampler()
    private let ioReportSampler = IOReportMetricsSampler()
    private var cachedCPUFrequencySample: CPUFrequencySample = .unavailable
    private var lastCPUFrequencySampleDate: Date?
    private var cachedThermalSample: ThermalSample = .unavailable
    private var lastThermalSampleDate: Date?

    public init() {}

    public func sample() -> SystemMetricsSnapshot {
        autoreleasepool {
            let timestamp = Date()
            let ioReportReading = ioReportSampler.sample()

            return SystemMetricsSnapshot(
                timestamp: timestamp,
                cpu: cpuSampler.sample(powerWatts: ioReportReading.cpuPowerWatts),
                cpuFrequency: sampleCPUFrequency(at: timestamp),
                memory: memorySampler.sample(powerWatts: ioReportReading.dramPowerWatts),
                gpu: gpuSampler.sample(ioReportReading: ioReportReading),
                ane: aneSampler.sample(ioReportReading: ioReportReading),
                totalPower: ioReportReading.totalPowerWatts.map { TotalPowerSample(watts: $0) },
                thermal: sampleThermalMetrics(at: timestamp)
            )
        }
    }

    private func sampleCPUFrequency(at timestamp: Date) -> CPUFrequencySample {
        if let lastCPUFrequencySampleDate,
           timestamp.timeIntervalSince(lastCPUFrequencySampleDate) < Self.cpuFrequencyRefreshInterval
        {
            return cachedCPUFrequencySample
        }

        let cpuFrequencySample = cpuFrequencySampler.sample()
        cachedCPUFrequencySample = cpuFrequencySample
        lastCPUFrequencySampleDate = timestamp
        return cpuFrequencySample
    }

    private func sampleThermalMetrics(at timestamp: Date) -> ThermalSample {
        if let lastThermalSampleDate,
           timestamp.timeIntervalSince(lastThermalSampleDate) < Self.thermalRefreshInterval
        {
            return cachedThermalSample
        }

        let thermalSample = thermalSampler.sample()
        cachedThermalSample = thermalSample
        lastThermalSampleDate = timestamp
        return thermalSample
    }
}

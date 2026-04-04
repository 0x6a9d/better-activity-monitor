import Foundation

public final class SystemMetricsSampler {
    private static let thermalRefreshInterval: TimeInterval = 3

    private let cpuSampler = CPUSampler()
    private let cpuFrequencySampler = CPUFrequencySampler()
    private let memorySampler = MemorySampler()
    private let gpuSampler = GPUSampler()
    private let aneSampler = ANESampler()
    private let thermalSampler = ThermalSampler()
    private let ioReportSampler = IOReportMetricsSampler()
    private var cachedThermalSample: ThermalSample = .unavailable
    private var lastThermalSampleDate: Date?

    public init() {}

    public func sample() -> SystemMetricsSnapshot {
        let timestamp = Date()
        let ioReportReading = ioReportSampler.sample()

        return SystemMetricsSnapshot(
            timestamp: timestamp,
            cpu: cpuSampler.sample(powerWatts: ioReportReading.cpuPowerWatts),
            cpuFrequency: cpuFrequencySampler.sample(),
            memory: memorySampler.sample(powerWatts: ioReportReading.dramPowerWatts),
            gpu: gpuSampler.sample(ioReportReading: ioReportReading),
            ane: aneSampler.sample(ioReportReading: ioReportReading),
            totalPower: ioReportReading.totalPowerWatts.map { TotalPowerSample(watts: $0) },
            thermal: sampleThermalMetrics(at: timestamp)
        )
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

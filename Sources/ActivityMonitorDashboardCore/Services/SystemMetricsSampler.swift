import Foundation

public final class SystemMetricsSampler {
    private let cpuSampler = CPUSampler()
    private let cpuFrequencySampler = CPUFrequencySampler()
    private let memorySampler = MemorySampler()
    private let gpuSampler = GPUSampler()
    private let aneSampler = ANESampler()
    private let thermalSampler = ThermalSampler()
    private let ioReportSampler = IOReportMetricsSampler()

    public init() {}

    public func sample() -> SystemMetricsSnapshot {
        let ioReportReading = ioReportSampler.sample()

        return SystemMetricsSnapshot(
            timestamp: Date(),
            cpu: cpuSampler.sample(powerWatts: ioReportReading.cpuPowerWatts),
            cpuFrequency: cpuFrequencySampler.sample(),
            memory: memorySampler.sample(powerWatts: ioReportReading.dramPowerWatts),
            gpu: gpuSampler.sample(ioReportReading: ioReportReading),
            ane: aneSampler.sample(ioReportReading: ioReportReading),
            totalPower: ioReportReading.totalPowerWatts.map { TotalPowerSample(watts: $0) },
            thermal: thermalSampler.sample()
        )
    }
}

import Foundation

public struct SystemMetricsSnapshot: Sendable {
    public let timestamp: Date
    public let cpu: CPUSample
    public let cpuFrequency: CPUFrequencySample
    public let memory: MemorySample
    public let gpu: GPUSample
    public let ane: ANESample
    public let totalPower: TotalPowerSample?
    public let thermal: ThermalSample

    public init(
        timestamp: Date,
        cpu: CPUSample,
        cpuFrequency: CPUFrequencySample,
        memory: MemorySample,
        gpu: GPUSample,
        ane: ANESample,
        totalPower: TotalPowerSample?,
        thermal: ThermalSample
    ) {
        self.timestamp = timestamp
        self.cpu = cpu
        self.cpuFrequency = cpuFrequency
        self.memory = memory
        self.gpu = gpu
        self.ane = ane
        self.totalPower = totalPower
        self.thermal = thermal
    }

    public var totalPowerWatts: Double? {
        totalPower?.watts
    }
}

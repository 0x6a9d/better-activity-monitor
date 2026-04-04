import Foundation
import Combine
import ActivityMonitorDashboardCore

private struct DashboardMetricsState {
    var cpuSamples: [CPUSample] = []
    var cpuFrequencySamples: [CPUFrequencySample] = []
    var memorySamples: [MemorySample] = []
    var gpuSamples: [GPUSample] = []
    var aneSamples: [ANESample] = []
    var totalPowerSamples: [TotalPowerSample] = []
    var thermalSamples: [ThermalSample] = []
    var thermalSample: ThermalSample = .unavailable
    var processLeaders: ProcessLeadersSnapshot = .empty
    var lastUpdated: Date?

    var latestCPU: CPUSample? {
        cpuSamples.last
    }

    var latestMemory: MemorySample? {
        memorySamples.last
    }

    var latestCPUFrequency: CPUFrequencySample? {
        cpuFrequencySamples.last(where: \.isAvailable) ?? cpuFrequencySamples.last
    }

    var latestGPU: GPUSample? {
        gpuSamples.last
    }

    var latestANE: ANESample? {
        aneSamples.last
    }

    var latestTotalPower: TotalPowerSample? {
        totalPowerSamples.last
    }
}

private actor MetricsSamplingCoordinator {
    private let sampler = SystemMetricsSampler()

    func sample() -> SystemMetricsSnapshot {
        sampler.sample()
    }
}

@MainActor
final class DashboardViewModel: ObservableObject {
    static let historyCapacity = 90
    private static let refreshInterval: Duration = .seconds(1)
    private static let cpuMemoryLeaderRefreshInterval: TimeInterval = 8
    private static let gpuLeaderRefreshInterval: TimeInterval = 5

    @Published private var metrics = DashboardMetricsState()

    private let samplingCoordinator = MetricsSamplingCoordinator()
    private let processLeaderSampler = ProcessLeaderSampler()
    private var cpuHistory = HistoryBuffer<CPUSample>(capacity: historyCapacity)
    private var cpuFrequencyHistory = HistoryBuffer<CPUFrequencySample>(capacity: historyCapacity)
    private var memoryHistory = HistoryBuffer<MemorySample>(capacity: historyCapacity)
    private var gpuHistory = HistoryBuffer<GPUSample>(capacity: historyCapacity)
    private var aneHistory = HistoryBuffer<ANESample>(capacity: historyCapacity)
    private var totalPowerHistory = HistoryBuffer<TotalPowerSample>(capacity: historyCapacity)
    private var thermalHistory = HistoryBuffer<ThermalSample>(capacity: historyCapacity)
    private var refreshTask: Task<Void, Never>?
    private var cpuMemoryLeaderTask: Task<Void, Never>?
    private var gpuLeaderTask: Task<Void, Never>?
    private var lastCPUMemoryLeaderRequestDate: Date?
    private var lastGPULeaderRequestDate: Date?

    var cpuSamples: [CPUSample] {
        metrics.cpuSamples
    }

    var cpuFrequencySamples: [CPUFrequencySample] {
        metrics.cpuFrequencySamples
    }

    var memorySamples: [MemorySample] {
        metrics.memorySamples
    }

    var gpuSamples: [GPUSample] {
        metrics.gpuSamples
    }

    var aneSamples: [ANESample] {
        metrics.aneSamples
    }

    var totalPowerSamples: [TotalPowerSample] {
        metrics.totalPowerSamples
    }

    var thermalSamples: [ThermalSample] {
        metrics.thermalSamples
    }

    var thermalSample: ThermalSample {
        metrics.thermalSample
    }

    var processLeaders: ProcessLeadersSnapshot {
        metrics.processLeaders
    }

    var lastUpdated: Date? {
        metrics.lastUpdated
    }

    var latestCPU: CPUSample? {
        metrics.latestCPU
    }

    var latestMemory: MemorySample? {
        metrics.latestMemory
    }

    var latestCPUFrequency: CPUFrequencySample? {
        metrics.latestCPUFrequency
    }

    var latestGPU: GPUSample? {
        metrics.latestGPU
    }

    var latestANE: ANESample? {
        metrics.latestANE
    }

    var latestTotalPower: TotalPowerSample? {
        metrics.latestTotalPower
    }

    func start() {
        guard refreshTask == nil else {
            return
        }

        let samplingCoordinator = self.samplingCoordinator
        let refreshInterval = Self.refreshInterval

        refreshTask = Task.detached(priority: .utility) { [weak self, samplingCoordinator, refreshInterval] in
            while !Task.isCancelled {
                guard let self else {
                    return
                }

                let snapshot = await samplingCoordinator.sample()
                guard !Task.isCancelled else {
                    return
                }

                await self.apply(snapshot: snapshot)

                do {
                    try await Task.sleep(for: refreshInterval)
                } catch {
                    return
                }
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
        cpuMemoryLeaderTask?.cancel()
        cpuMemoryLeaderTask = nil
        gpuLeaderTask?.cancel()
        gpuLeaderTask = nil
    }

    private func apply(snapshot: SystemMetricsSnapshot) {
        cpuHistory.append(snapshot.cpu)
        cpuFrequencyHistory.append(snapshot.cpuFrequency)
        memoryHistory.append(snapshot.memory)
        gpuHistory.append(snapshot.gpu)
        aneHistory.append(snapshot.ane)
        if let totalPower = snapshot.totalPower {
            totalPowerHistory.append(totalPower)
        }
        thermalHistory.append(snapshot.thermal)

        metrics = DashboardMetricsState(
            cpuSamples: cpuHistory.values,
            cpuFrequencySamples: cpuFrequencyHistory.values,
            memorySamples: memoryHistory.values,
            gpuSamples: gpuHistory.values,
            aneSamples: aneHistory.values,
            totalPowerSamples: totalPowerHistory.values,
            thermalSamples: thermalHistory.values,
            thermalSample: snapshot.thermal,
            processLeaders: metrics.processLeaders,
            lastUpdated: snapshot.timestamp
        )

        let timestamp = snapshot.timestamp
        refreshGPULeaderIfNeeded(at: timestamp, overallUtilization: snapshot.gpu.utilization)
        refreshCPUMemoryLeadersIfNeeded(at: timestamp)
    }

    private func refreshGPULeaderIfNeeded(at timestamp: Date, overallUtilization: Double) {
        guard gpuLeaderTask == nil else {
            return
        }

        guard shouldRefreshLeader(
            lastRequestDate: lastGPULeaderRequestDate,
            at: timestamp,
            interval: Self.gpuLeaderRefreshInterval
        ) else {
            return
        }

        lastGPULeaderRequestDate = timestamp
        gpuLeaderTask = Task { [weak self] in
            guard let self else {
                return
            }

            let gpuLeader = await processLeaderSampler.sampleGPULeaderIfNeeded(
                at: timestamp,
                overallUtilization: overallUtilization,
                minimumRefreshInterval: Self.gpuLeaderRefreshInterval
            )

            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                var updatedMetrics = self.metrics
                updatedMetrics.processLeaders = ProcessLeadersSnapshot(
                    cpu: self.metrics.processLeaders.cpu,
                    memory: self.metrics.processLeaders.memory,
                    gpu: gpuLeader
                )
                self.metrics = updatedMetrics
                self.gpuLeaderTask = nil
            }
        }
    }

    private func refreshCPUMemoryLeadersIfNeeded(at timestamp: Date) {
        guard cpuMemoryLeaderTask == nil else {
            return
        }

        guard shouldRefreshLeader(
            lastRequestDate: lastCPUMemoryLeaderRequestDate,
            at: timestamp,
            interval: Self.cpuMemoryLeaderRefreshInterval
        ) else {
            return
        }

        lastCPUMemoryLeaderRequestDate = timestamp
        cpuMemoryLeaderTask = Task { [weak self] in
            guard let self else {
                return
            }

            let leaders = await processLeaderSampler.sampleCPUMemoryLeadersIfNeeded(
                at: timestamp,
                minimumRefreshInterval: Self.cpuMemoryLeaderRefreshInterval
            )

            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                var updatedMetrics = self.metrics
                updatedMetrics.processLeaders = ProcessLeadersSnapshot(
                    cpu: leaders.cpu,
                    memory: leaders.memory,
                    gpu: self.metrics.processLeaders.gpu
                )
                self.metrics = updatedMetrics
                self.cpuMemoryLeaderTask = nil
            }
        }
    }

    private func shouldRefreshLeader(
        lastRequestDate: Date?,
        at timestamp: Date,
        interval: TimeInterval
    ) -> Bool {
        guard let lastRequestDate else {
            return true
        }

        return timestamp.timeIntervalSince(lastRequestDate) >= interval
    }
}

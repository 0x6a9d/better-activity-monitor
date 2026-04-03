import Foundation
import Combine
import ActivityMonitorDashboardCore

@MainActor
final class DashboardViewModel: ObservableObject {
    static let historyCapacity = 90
    private static let cpuMemoryLeaderRefreshInterval: TimeInterval = 5
    private static let gpuLeaderRefreshInterval: TimeInterval = 3

    @Published private(set) var cpuSamples: [CPUSample] = []
    @Published private(set) var cpuFrequencySamples: [CPUFrequencySample] = []
    @Published private(set) var memorySamples: [MemorySample] = []
    @Published private(set) var gpuSamples: [GPUSample] = []
    @Published private(set) var aneSamples: [ANESample] = []
    @Published private(set) var totalPowerSamples: [TotalPowerSample] = []
    @Published private(set) var thermalSamples: [ThermalSample] = []
    @Published private(set) var thermalSample: ThermalSample = .unavailable
    @Published private(set) var processLeaders: ProcessLeadersSnapshot = .empty
    @Published private(set) var lastUpdated: Date?

    private let sampler = SystemMetricsSampler()
    private let processLeaderSampler = ProcessLeaderSampler()
    private var cpuHistory = HistoryBuffer<CPUSample>(capacity: historyCapacity)
    private var cpuFrequencyHistory = HistoryBuffer<CPUFrequencySample>(capacity: historyCapacity)
    private var memoryHistory = HistoryBuffer<MemorySample>(capacity: historyCapacity)
    private var gpuHistory = HistoryBuffer<GPUSample>(capacity: historyCapacity)
    private var aneHistory = HistoryBuffer<ANESample>(capacity: historyCapacity)
    private var totalPowerHistory = HistoryBuffer<TotalPowerSample>(capacity: historyCapacity)
    private var thermalHistory = HistoryBuffer<ThermalSample>(capacity: historyCapacity)
    private var timer: Timer?
    private var cpuMemoryLeaderTask: Task<Void, Never>?
    private var gpuLeaderTask: Task<Void, Never>?
    private var lastCPUMemoryLeaderRequestDate: Date?
    private var lastGPULeaderRequestDate: Date?

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

    func start() {
        guard timer == nil else {
            return
        }

        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        cpuMemoryLeaderTask?.cancel()
        cpuMemoryLeaderTask = nil
        gpuLeaderTask?.cancel()
        gpuLeaderTask = nil
    }

    private func refresh() {
        let snapshot = sampler.sample()

        cpuHistory.append(snapshot.cpu)
        cpuFrequencyHistory.append(snapshot.cpuFrequency)
        memoryHistory.append(snapshot.memory)
        gpuHistory.append(snapshot.gpu)
        aneHistory.append(snapshot.ane)
        if let totalPower = snapshot.totalPower {
            totalPowerHistory.append(totalPower)
        }
        thermalHistory.append(snapshot.thermal)

        cpuSamples = cpuHistory.values
        cpuFrequencySamples = cpuFrequencyHistory.values
        memorySamples = memoryHistory.values
        gpuSamples = gpuHistory.values
        aneSamples = aneHistory.values
        totalPowerSamples = totalPowerHistory.values
        thermalSamples = thermalHistory.values
        thermalSample = snapshot.thermal
        lastUpdated = snapshot.timestamp

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
                self.processLeaders = ProcessLeadersSnapshot(
                    cpu: self.processLeaders.cpu,
                    memory: self.processLeaders.memory,
                    gpu: gpuLeader
                )
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
                self.processLeaders = ProcessLeadersSnapshot(
                    cpu: leaders.cpu,
                    memory: leaders.memory,
                    gpu: self.processLeaders.gpu
                )
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

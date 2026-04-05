import Foundation
import Combine
import ActivityMonitorDashboardCore

private actor MetricsSamplingCoordinator {
    private let sampler = SystemMetricsSampler()

    func sample() -> SystemMetricsSnapshot {
        sampler.sample()
    }
}

@MainActor
final class DashboardViewModel: ObservableObject {
    static let historyCapacity = 90
    private static let refreshInterval: Duration = .seconds(2)
    private static let cpuMemoryLeaderRefreshInterval: TimeInterval = 30
    private static let gpuLeaderRefreshInterval: TimeInterval = 20

    let cpuLoadPanel = CPULoadPanelModel(initialState: CPULoadPanelState())
    let cpuFrequencyPanel = CPUFrequencyPanelModel(initialState: CPUFrequencyPanelState())
    let memoryPressurePanel = MemoryPressurePanelModel(initialState: MemoryPressurePanelState())
    let gpuPressurePanel = GPUPressurePanelModel(initialState: GPUPressurePanelState())
    let aneUsagePanel = ANEUsagePanelModel(initialState: ANEUsagePanelState())
    let totalPowerPanel = TotalPowerPanelModel(initialState: TotalPowerPanelState())
    let thermalStatePanel = ThermalStatePanelModel(initialState: ThermalStatePanelState())
    let fanSpeedPanel = FanSpeedPanelModel(initialState: FanSpeedPanelState())

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
        cpuFrequencyHistory.appendIfChanged(snapshot.cpuFrequency)
        memoryHistory.append(snapshot.memory)
        gpuHistory.append(snapshot.gpu)
        aneHistory.append(snapshot.ane)
        if let totalPower = snapshot.totalPower {
            totalPowerHistory.append(totalPower)
        }
        thermalHistory.appendIfChanged(snapshot.thermal)

        let thermalSample = thermalHistory.last ?? snapshot.thermal

        updateCPULoadPanel(using: thermalSample)
        updateCPUFrequencyPanel()
        updateMemoryPressurePanel(using: thermalSample)
        updateGPUPressurePanel(using: thermalSample)
        updateANEUsagePanel(using: thermalSample)
        updateTotalPowerPanel()
        updateThermalPanels(using: thermalSample)

        let timestamp = snapshot.timestamp
        refreshGPULeaderIfNeeded(at: timestamp, overallUtilization: snapshot.gpu.utilization)
        refreshCPUMemoryLeadersIfNeeded(at: timestamp)
    }

    private func updateCPULoadPanel(using thermalSample: ThermalSample) {
        let samples = cpuHistory.values
        cpuLoadPanel.setState(
            CPULoadPanelState(
                latestSample: cpuHistory.last ?? CPULoadPanelState().latestSample,
                samples: samples,
                cpuTemperatureCelsius: thermalSample.cpuTemperatureCelsius,
                averageUsage: average(samples.map(\.totalUsage)),
                leader: cpuLoadPanel.state.leader
            )
        )
    }

    private func updateCPUFrequencyPanel() {
        let samples = cpuFrequencyHistory.values
        cpuFrequencyPanel.setState(
            CPUFrequencyPanelState(
                latestSample: samples.last(where: \.isAvailable) ?? samples.last ?? .unavailable,
                samples: samples,
                averageGHz: average(samples.filter(\.isAvailable).map(\.overallGHz))
            )
        )
    }

    private func updateMemoryPressurePanel(using thermalSample: ThermalSample) {
        let samples = memoryHistory.values
        memoryPressurePanel.setState(
            MemoryPressurePanelState(
                latestSample: memoryHistory.last ?? MemoryPressurePanelState().latestSample,
                histogramSamples: samples.map(\.histogramSample),
                socTemperatureCelsius: thermalSample.socTemperatureCelsius,
                averagePressure: average(samples.map(\.pressure)),
                leader: memoryPressurePanel.state.leader
            )
        )
    }

    private func updateGPUPressurePanel(using thermalSample: ThermalSample) {
        let samples = gpuHistory.values
        gpuPressurePanel.setState(
            GPUPressurePanelState(
                latestSample: gpuHistory.last ?? .unavailable,
                histogramSamples: samples.map(\.histogramSample),
                gpuTemperatureCelsius: thermalSample.gpuTemperatureCelsius,
                averageUsage: average(samples.filter(\.isAvailable).map(\.utilization)),
                leader: gpuPressurePanel.state.leader
            )
        )
    }

    private func updateANEUsagePanel(using thermalSample: ThermalSample) {
        let samples = aneHistory.values
        aneUsagePanel.setState(
            ANEUsagePanelState(
                latestSample: aneHistory.last ?? .unavailable,
                histogramSamples: samples.map(\.histogramSample),
                socTemperatureCelsius: thermalSample.socTemperatureCelsius,
                averageUsage: average(samples.filter(\.isAvailable).map(\.utilization))
            )
        )
    }

    private func updateTotalPowerPanel() {
        let samples = totalPowerHistory.values
        let measuredMaximum = samples.map(\.watts).max() ?? 0
        totalPowerPanel.setState(
            TotalPowerPanelState(
                samples: samples,
                currentWatts: totalPowerHistory.last?.watts,
                averageWatts: average(samples.map(\.watts)),
                displayMaximumWatts: max(10, measuredMaximum * 1.15)
            )
        )
    }

    private func updateThermalPanels(using thermalSample: ThermalSample) {
        let samples = thermalHistory.values
        thermalStatePanel.setState(
            ThermalStatePanelState(
                latestSample: thermalSample,
                samples: samples,
                averageTemperatureCelsius: average(samples.compactMap(\.displayTemperatureCelsius))
            )
        )
        fanSpeedPanel.setState(
            FanSpeedPanelState(
                latestSample: thermalSample,
                samples: samples,
                averageFanSpeedRPM: average(samples.compactMap(\.fanSpeedRPM))
            )
        )
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
                self.gpuPressurePanel.update { state in
                    var updatedState = state
                    updatedState.leader = gpuLeader
                    return updatedState
                }
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
                self.cpuLoadPanel.update { state in
                    var updatedState = state
                    updatedState.leader = leaders.cpu
                    return updatedState
                }
                self.memoryPressurePanel.update { state in
                    var updatedState = state
                    updatedState.leader = leaders.memory
                    return updatedState
                }
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

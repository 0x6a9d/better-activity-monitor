import Foundation
import Combine
import ActivityMonitorDashboardCore

@MainActor
final class PanelStore<State: Equatable>: ObservableObject {
    @Published private(set) var state: State

    init(initialState: State) {
        self.state = initialState
    }

    func setState(_ newState: State) {
        guard state != newState else {
            return
        }

        state = newState
    }

    func update(_ transform: (State) -> State) {
        setState(transform(state))
    }
}

typealias CPULoadPanelModel = PanelStore<CPULoadPanelState>
typealias CPUFrequencyPanelModel = PanelStore<CPUFrequencyPanelState>
typealias MemoryPressurePanelModel = PanelStore<MemoryPressurePanelState>
typealias GPUPressurePanelModel = PanelStore<GPUPressurePanelState>
typealias ANEUsagePanelModel = PanelStore<ANEUsagePanelState>
typealias TotalPowerPanelModel = PanelStore<TotalPowerPanelState>
typealias ThermalStatePanelModel = PanelStore<ThermalStatePanelState>
typealias FanSpeedPanelModel = PanelStore<FanSpeedPanelState>

private let defaultCPUSample = CPUSample(userUsage: 0, systemUsage: 0, idleUsage: 1)
private let defaultMemorySample = MemorySample(
    pressure: 0,
    level: .good,
    usedBytes: 0,
    cachedBytes: 0,
    compressedBytes: 0,
    freeBytes: 0,
    physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory
)

func average(_ values: [Double]) -> Double? {
    guard !values.isEmpty else {
        return nil
    }

    return values.reduce(0, +) / Double(values.count)
}

struct CPULoadPanelState: Equatable {
    var latestSample: CPUSample = defaultCPUSample
    var samples: [CPUSample] = []
    var cpuTemperatureCelsius: Double?
    var averageUsage: Double?
    var leader: ProcessLeader?
}

struct CPUFrequencyPanelState: Equatable {
    var latestSample: CPUFrequencySample = .unavailable
    var samples: [CPUFrequencySample] = []
    var averageGHz: Double?
}

struct MemoryPressurePanelState: Equatable {
    var latestSample: MemorySample = defaultMemorySample
    var histogramSamples: [PressureHistogramSample] = []
    var socTemperatureCelsius: Double?
    var averagePressure: Double?
    var leader: ProcessLeader?
}

struct GPUPressurePanelState: Equatable {
    var latestSample: GPUSample = .unavailable
    var histogramSamples: [PressureHistogramSample] = []
    var gpuTemperatureCelsius: Double?
    var averageUsage: Double?
    var leader: ProcessLeader?
}

struct ANEUsagePanelState: Equatable {
    var latestSample: ANESample = .unavailable
    var histogramSamples: [PressureHistogramSample] = []
    var socTemperatureCelsius: Double?
    var averageUsage: Double?
}

struct TotalPowerPanelState: Equatable {
    var samples: [TotalPowerSample] = []
    var currentWatts: Double?
    var averageWatts: Double?
    var displayMaximumWatts: Double = 10
}

struct ThermalStatePanelState: Equatable {
    var latestSample: ThermalSample = .unavailable
    var samples: [ThermalSample] = []
    var averageTemperatureCelsius: Double?
}

struct FanSpeedPanelState: Equatable {
    var latestSample: ThermalSample = .unavailable
    var samples: [ThermalSample] = []
    var averageFanSpeedRPM: Double?
}

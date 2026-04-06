import Foundation

public enum CPUFrequencyTierLabel: String, Sendable {
    case efficiency
    case performance
    case superTier

    public var displayName: String {
        switch self {
        case .efficiency:
            "Efficiency"
        case .performance:
            "Performance"
        case .superTier:
            "Super"
        }
    }
}

public struct CPUSample: Sendable, Equatable {
    public let userUsage: Double
    public let systemUsage: Double
    public let idleUsage: Double
    public let powerWatts: Double?

    public init(userUsage: Double, systemUsage: Double, idleUsage: Double, powerWatts: Double? = nil) {
        self.userUsage = userUsage.clamped(to: 0...1)
        self.systemUsage = systemUsage.clamped(to: 0...1)
        self.idleUsage = idleUsage.clamped(to: 0...1)
        self.powerWatts = powerWatts.map { max(0, $0) }
    }

    public var totalUsage: Double {
        (userUsage + systemUsage).clamped(to: 0...1)
    }
}

public struct CPUFrequencySample: Sendable, Equatable {
    public let performanceGHz: Double
    public let superGHz: Double
    public let performanceMaxGHz: Double
    public let superMaxGHz: Double
    public let performanceCoreCount: Int
    public let superCoreCount: Int
    public let performanceTierLabel: CPUFrequencyTierLabel
    public let superTierLabel: CPUFrequencyTierLabel
    public let isAvailable: Bool

    public init(
        performanceGHz: Double,
        superGHz: Double,
        performanceMaxGHz: Double,
        superMaxGHz: Double,
        performanceCoreCount: Int,
        superCoreCount: Int,
        performanceTierLabel: CPUFrequencyTierLabel = .performance,
        superTierLabel: CPUFrequencyTierLabel = .superTier,
        isAvailable: Bool
    ) {
        self.performanceGHz = max(0, performanceGHz)
        self.superGHz = max(0, superGHz)
        self.performanceMaxGHz = max(0, performanceMaxGHz)
        self.superMaxGHz = max(0, superMaxGHz)
        self.performanceCoreCount = max(0, performanceCoreCount)
        self.superCoreCount = max(0, superCoreCount)
        self.performanceTierLabel = performanceTierLabel
        self.superTierLabel = superTierLabel
        self.isAvailable = isAvailable
    }

    public static let unavailable = CPUFrequencySample(
        performanceGHz: 0,
        superGHz: 0,
        performanceMaxGHz: 0,
        superMaxGHz: 0,
        performanceCoreCount: 0,
        superCoreCount: 0,
        performanceTierLabel: .performance,
        superTierLabel: .superTier,
        isAvailable: false
    )

    public var performanceTierDisplayName: String {
        performanceTierLabel.displayName
    }

    public var superTierDisplayName: String {
        superTierLabel.displayName
    }

    public var overallGHz: Double {
        let weightedCoreCount = performanceCoreCount + superCoreCount

        guard weightedCoreCount > 0 else {
            let availableValues = [performanceGHz, superGHz].filter { $0 > 0 }
            guard !availableValues.isEmpty else {
                return 0
            }

            return availableValues.reduce(0, +) / Double(availableValues.count)
        }

        let weightedSum = (performanceGHz * Double(performanceCoreCount)) + (superGHz * Double(superCoreCount))
        return weightedSum / Double(weightedCoreCount)
    }

    public var performanceNormalized: Double {
        guard performanceMaxGHz > 0 else {
            return 0
        }

        return (performanceGHz / performanceMaxGHz).clamped(to: 0...1)
    }

    public var superNormalized: Double {
        guard superMaxGHz > 0 else {
            return 0
        }

        return (superGHz / superMaxGHz).clamped(to: 0...1)
    }
}

public struct PressureHistogramSample: Sendable, Equatable {
    public let value: Double
    public let level: PressureLevel

    public init(value: Double, level: PressureLevel) {
        self.value = value.clamped(to: 0...1)
        self.level = level
    }
}

public struct MemorySample: Sendable, Equatable {
    public let pressure: Double
    public let level: PressureLevel
    public let usedBytes: UInt64
    public let cachedBytes: UInt64
    public let compressedBytes: UInt64
    public let freeBytes: UInt64
    public let physicalMemoryBytes: UInt64
    public let powerWatts: Double?

    public init(
        pressure: Double,
        level: PressureLevel,
        usedBytes: UInt64,
        cachedBytes: UInt64,
        compressedBytes: UInt64,
        freeBytes: UInt64,
        physicalMemoryBytes: UInt64,
        powerWatts: Double? = nil
    ) {
        self.pressure = pressure.clamped(to: 0...1)
        self.level = level
        self.usedBytes = usedBytes
        self.cachedBytes = cachedBytes
        self.compressedBytes = compressedBytes
        self.freeBytes = freeBytes
        self.physicalMemoryBytes = physicalMemoryBytes
        self.powerWatts = powerWatts.map { max(0, $0) }
    }

    public var histogramSample: PressureHistogramSample {
        PressureHistogramSample(value: pressure, level: level)
    }
}

public struct GPUSample: Sendable, Equatable {
    public let utilization: Double
    public let level: PressureLevel
    public let isAvailable: Bool
    public let powerWatts: Double?

    public init(
        utilization: Double,
        level: PressureLevel,
        isAvailable: Bool,
        powerWatts: Double? = nil
    ) {
        self.utilization = utilization.clamped(to: 0...1)
        self.level = level
        self.isAvailable = isAvailable
        self.powerWatts = powerWatts.map { max(0, $0) }
    }

    public static let unavailable = GPUSample(
        utilization: 0,
        level: .good,
        isAvailable: false,
        powerWatts: nil
    )

    public var histogramSample: PressureHistogramSample {
        PressureHistogramSample(value: utilization, level: level)
    }
}

public struct ANESample: Sendable, Equatable {
    public let utilization: Double
    public let powerWatts: Double
    public let level: PressureLevel
    public let isAvailable: Bool

    public init(
        utilization: Double,
        powerWatts: Double,
        level: PressureLevel,
        isAvailable: Bool
    ) {
        self.utilization = utilization.clamped(to: 0...1)
        self.powerWatts = max(0, powerWatts)
        self.level = level
        self.isAvailable = isAvailable
    }

    public static let unavailable = ANESample(
        utilization: 0,
        powerWatts: 0,
        level: .good,
        isAvailable: false
    )

    public var histogramSample: PressureHistogramSample {
        PressureHistogramSample(value: utilization, level: level)
    }
}

public struct TotalPowerSample: Sendable, Equatable {
    public let watts: Double

    public init(watts: Double) {
        self.watts = max(0, watts)
    }
}

public enum ThermalStateStatus: Sendable, Equatable {
    case normal
    case fair
    case serious
    case critical
    case unknown

    public var title: String {
        switch self {
        case .normal:
            "Normal"
        case .fair:
            "Normal"
        case .serious:
            "Serious"
        case .critical:
            "Critical"
        case .unknown:
            "Unknown"
        }
    }
}

public struct FanReading: Sendable, Equatable, Identifiable {
    public var id: Int { number }

    public let number: Int
    public let currentRPM: Double
    public let maximumRPM: Double?

    public init(number: Int, currentRPM: Double, maximumRPM: Double?) {
        self.number = number
        self.currentRPM = max(0, currentRPM)
        self.maximumRPM = maximumRPM.map { max(0, $0) }
    }

    public var normalizedSpeed: Double? {
        guard let maximumRPM, maximumRPM > 0 else {
            return nil
        }

        return (currentRPM / maximumRPM).clamped(to: 0...1)
    }

    public var isActive: Bool {
        currentRPM > 0
    }
}

public struct ThermalSample: Sendable, Equatable {
    public let thermalState: ThermalStateStatus
    public let socTemperatureCelsius: Double?
    public let cpuTemperatureCelsius: Double?
    public let gpuTemperatureCelsius: Double?
    public let fans: [FanReading]

    public init(
        thermalState: ThermalStateStatus,
        socTemperatureCelsius: Double?,
        cpuTemperatureCelsius: Double?,
        gpuTemperatureCelsius: Double?,
        fans: [FanReading]
    ) {
        self.thermalState = thermalState
        self.socTemperatureCelsius = socTemperatureCelsius
        self.cpuTemperatureCelsius = cpuTemperatureCelsius
        self.gpuTemperatureCelsius = gpuTemperatureCelsius
        self.fans = fans
    }

    public static let unavailable = ThermalSample(
        thermalState: .unknown,
        socTemperatureCelsius: nil,
        cpuTemperatureCelsius: nil,
        gpuTemperatureCelsius: nil,
        fans: []
    )

    public var internalTemperatureCelsius: Double? {
        socTemperatureCelsius
    }

    public var displayTemperatureCelsius: Double? {
        socTemperatureCelsius ?? cpuTemperatureCelsius ?? gpuTemperatureCelsius
    }

    public var fanCount: Int {
        fans.count
    }

    public func fan(number: Int) -> FanReading? {
        fans.first { $0.number == number }
    }

    public var fanSpeedRPM: Double? {
        guard !fans.isEmpty else {
            return nil
        }

        return fans.map(\.currentRPM).reduce(0, +) / Double(fans.count)
    }

    public var fanSpeedPercent: Double? {
        let percentages = fans.compactMap(\.normalizedSpeed)
        guard !percentages.isEmpty else {
            return nil
        }

        return percentages.reduce(0, +) / Double(percentages.count)
    }

    public var maximumFanRPM: Double? {
        fans.compactMap(\.maximumRPM).max()
    }

    public var fansAreActive: Bool {
        fans.contains(where: \.isActive)
    }

    public var isAvailable: Bool {
        thermalState != .unknown ||
        socTemperatureCelsius != nil ||
        cpuTemperatureCelsius != nil ||
        gpuTemperatureCelsius != nil ||
        !fans.isEmpty
    }
}

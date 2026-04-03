import Foundation
import CoreFoundation
import Darwin

struct IOReportMetricsReading {
    let gpuUtilization: Double?
    let cpuPowerWatts: Double?
    let gpuPowerWatts: Double?
    let dramPowerWatts: Double?
    let anePowerWatts: Double?
    let totalPowerWatts: Double?
}

final class IOReportMetricsSampler {
    private typealias IOReportSubscriptionRef = OpaquePointer

    private typealias CopyChannelsInGroupFn = @convention(c) (
        CFString,
        CFString?,
        UInt64,
        UInt64,
        UInt64
    ) -> Unmanaged<CFDictionary>?

    private typealias MergeChannelsFn = @convention(c) (
        CFDictionary,
        CFDictionary,
        CFTypeRef?
    ) -> Void

    private typealias CreateSubscriptionFn = @convention(c) (
        UnsafeRawPointer?,
        CFMutableDictionary,
        UnsafeMutablePointer<Unmanaged<CFMutableDictionary>?>?,
        UInt64,
        UnsafeRawPointer?
    ) -> IOReportSubscriptionRef?

    private typealias CreateSamplesFn = @convention(c) (
        IOReportSubscriptionRef,
        CFMutableDictionary,
        UnsafeRawPointer?
    ) -> Unmanaged<CFDictionary>?

    private typealias CreateSamplesDeltaFn = @convention(c) (
        CFDictionary,
        CFDictionary,
        UnsafeRawPointer?
    ) -> Unmanaged<CFDictionary>?

    private typealias SimpleGetIntegerValueFn = @convention(c) (CFDictionary, Int32) -> Int64
    private typealias ChannelGetGroupFn = @convention(c) (CFDictionary) -> Unmanaged<CFString>?
    private typealias ChannelGetSubGroupFn = @convention(c) (CFDictionary) -> Unmanaged<CFString>?
    private typealias ChannelGetChannelNameFn = @convention(c) (CFDictionary) -> Unmanaged<CFString>?
    private typealias ChannelGetUnitLabelFn = @convention(c) (CFDictionary) -> Unmanaged<CFString>?
    private typealias StateGetCountFn = @convention(c) (CFDictionary) -> Int32
    private typealias StateGetNameForIndexFn = @convention(c) (CFDictionary, Int32) -> Unmanaged<CFString>?
    private typealias StateGetResidencyFn = @convention(c) (CFDictionary, Int32) -> Int64

    private final class Functions: @unchecked Sendable {
        let handle: UnsafeMutableRawPointer
        let copyChannelsInGroup: CopyChannelsInGroupFn
        let mergeChannels: MergeChannelsFn
        let createSubscription: CreateSubscriptionFn
        let createSamples: CreateSamplesFn
        let createSamplesDelta: CreateSamplesDeltaFn
        let simpleGetIntegerValue: SimpleGetIntegerValueFn
        let channelGetGroup: ChannelGetGroupFn
        let channelGetSubGroup: ChannelGetSubGroupFn
        let channelGetChannelName: ChannelGetChannelNameFn
        let channelGetUnitLabel: ChannelGetUnitLabelFn
        let stateGetCount: StateGetCountFn
        let stateGetNameForIndex: StateGetNameForIndexFn
        let stateGetResidency: StateGetResidencyFn

        init?() {
            guard let handle = dlopen("/usr/lib/libIOReport.dylib", RTLD_LAZY) else {
                return nil
            }

            func loadSymbol<T>(_ name: String, as type: T.Type) -> T? {
                guard let symbol = dlsym(handle, name) else {
                    return nil
                }

                return unsafeBitCast(symbol, to: type)
            }

            guard
                let copyChannelsInGroup = loadSymbol("IOReportCopyChannelsInGroup", as: CopyChannelsInGroupFn.self),
                let mergeChannels = loadSymbol("IOReportMergeChannels", as: MergeChannelsFn.self),
                let createSubscription = loadSymbol("IOReportCreateSubscription", as: CreateSubscriptionFn.self),
                let createSamples = loadSymbol("IOReportCreateSamples", as: CreateSamplesFn.self),
                let createSamplesDelta = loadSymbol("IOReportCreateSamplesDelta", as: CreateSamplesDeltaFn.self),
                let simpleGetIntegerValue = loadSymbol("IOReportSimpleGetIntegerValue", as: SimpleGetIntegerValueFn.self),
                let channelGetGroup = loadSymbol("IOReportChannelGetGroup", as: ChannelGetGroupFn.self),
                let channelGetSubGroup = loadSymbol("IOReportChannelGetSubGroup", as: ChannelGetSubGroupFn.self),
                let channelGetChannelName = loadSymbol("IOReportChannelGetChannelName", as: ChannelGetChannelNameFn.self),
                let channelGetUnitLabel = loadSymbol("IOReportChannelGetUnitLabel", as: ChannelGetUnitLabelFn.self),
                let stateGetCount = loadSymbol("IOReportStateGetCount", as: StateGetCountFn.self),
                let stateGetNameForIndex = loadSymbol("IOReportStateGetNameForIndex", as: StateGetNameForIndexFn.self),
                let stateGetResidency = loadSymbol("IOReportStateGetResidency", as: StateGetResidencyFn.self)
            else {
                dlclose(handle)
                return nil
            }

            self.handle = handle
            self.copyChannelsInGroup = copyChannelsInGroup
            self.mergeChannels = mergeChannels
            self.createSubscription = createSubscription
            self.createSamples = createSamples
            self.createSamplesDelta = createSamplesDelta
            self.simpleGetIntegerValue = simpleGetIntegerValue
            self.channelGetGroup = channelGetGroup
            self.channelGetSubGroup = channelGetSubGroup
            self.channelGetChannelName = channelGetChannelName
            self.channelGetUnitLabel = channelGetUnitLabel
            self.stateGetCount = stateGetCount
            self.stateGetNameForIndex = stateGetNameForIndex
            self.stateGetResidency = stateGetResidency
        }

        deinit {
            dlclose(handle)
        }
    }

    private static let functions = Functions()
    private var subscription: IOReportSubscriptionRef?
    private var channels: CFMutableDictionary?
    private var previousSample: CFDictionary?
    private var previousSampleDate: Date?
    private var smcReader: AppleSMCReader?

    func sample() -> IOReportMetricsReading {
        guard prepareIfNeeded(),
              let functions = Self.functions,
              let subscription,
              let channels,
              let currentSample = functions.createSamples(subscription, channels, nil)?.takeRetainedValue()
        else {
            return IOReportMetricsReading(
                gpuUtilization: nil,
                cpuPowerWatts: nil,
                gpuPowerWatts: nil,
                dramPowerWatts: nil,
                anePowerWatts: nil,
                totalPowerWatts: totalSystemPowerWatts()
            )
        }

        let currentDate = Date()

        defer {
            previousSample = currentSample
            previousSampleDate = currentDate
        }

        guard let previousSample,
              let previousSampleDate,
              let deltaSample = functions.createSamplesDelta(previousSample, currentSample, nil)?.takeRetainedValue()
        else {
            return IOReportMetricsReading(
                gpuUtilization: nil,
                cpuPowerWatts: nil,
                gpuPowerWatts: nil,
                dramPowerWatts: nil,
                anePowerWatts: nil,
                totalPowerWatts: totalSystemPowerWatts()
            )
        }

        let elapsedMilliseconds = max(currentDate.timeIntervalSince(previousSampleDate) * 1000, 1)
        let energy = energyPowerSample(from: deltaSample, elapsedMilliseconds: elapsedMilliseconds, using: functions)
        let totalPower = totalSystemPowerWatts() ?? sumAvailable([
            energy.cpuPowerWatts,
            energy.gpuPowerWatts,
            energy.dramPowerWatts,
            energy.anePowerWatts
        ])

        return IOReportMetricsReading(
            gpuUtilization: activeGPUPercent(from: deltaSample, using: functions).map { ($0 / 100).clamped(to: 0...1) },
            cpuPowerWatts: energy.cpuPowerWatts,
            gpuPowerWatts: energy.gpuPowerWatts,
            dramPowerWatts: energy.dramPowerWatts,
            anePowerWatts: energy.anePowerWatts,
            totalPowerWatts: totalPower
        )
    }

    private func prepareIfNeeded() -> Bool {
        guard subscription == nil || channels == nil else {
            return true
        }

        guard let functions = Self.functions,
              let energyChannels = functions.copyChannelsInGroup("Energy Model" as CFString, nil, 0, 0, 0)?.takeRetainedValue(),
              let mutableChannels = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, energyChannels)
        else {
            return false
        }

        if let gpuChannels = functions.copyChannelsInGroup("GPU Stats" as CFString, nil, 0, 0, 0)?.takeRetainedValue() {
            functions.mergeChannels(mutableChannels, gpuChannels, nil)
        }

        var subsystem: Unmanaged<CFMutableDictionary>?

        guard let subscription = functions.createSubscription(nil, mutableChannels, &subsystem, 0, nil) else {
            return false
        }

        self.channels = mutableChannels
        self.subscription = subscription
        return true
    }

    private func activeGPUPercent(from sample: CFDictionary, using functions: Functions) -> Double? {
        guard let channelObjects = (sample as NSDictionary)["IOReportChannels"] as? [Any] else {
            return nil
        }

        var highestPercent: Double?

        for case let channel as CFDictionary in channelObjects {
            guard string(from: functions.channelGetGroup(channel)) == "GPU Stats",
                  string(from: functions.channelGetSubGroup(channel)) == "GPU Performance States",
                  string(from: functions.channelGetChannelName(channel)) == "GPUPH"
            else {
                continue
            }

            let stateCount = Int(functions.stateGetCount(channel))
            guard stateCount > 0 else {
                continue
            }

            var totalResidency: Int64 = 0
            var activeResidency: Int64 = 0

            for index in 0..<stateCount {
                let residency = functions.stateGetResidency(channel, Int32(index))
                totalResidency += residency

                let stateName = string(from: functions.stateGetNameForIndex(channel, Int32(index))) ?? ""
                if stateName != "OFF" && stateName != "IDLE" && stateName != "DOWN" {
                    activeResidency += residency
                }
            }

            guard totalResidency > 0 else {
                continue
            }

            let percent = (Double(activeResidency) / Double(totalResidency)) * 100
            highestPercent = max(highestPercent ?? 0, percent)
        }

        return highestPercent
    }

    private func energyPowerSample(
        from sample: CFDictionary,
        elapsedMilliseconds: Double,
        using functions: Functions
    ) -> EnergyPowerSample {
        guard let channelObjects = (sample as NSDictionary)["IOReportChannels"] as? [Any] else {
            return .empty
        }

        var cpuPower = 0.0
        var gpuPower = 0.0
        var dramPower = 0.0
        var anePower = 0.0
        var foundCPUChannel = false
        var foundGPUChannel = false
        var foundDRAMChannel = false
        var foundANEChannel = false

        for case let channel as CFDictionary in channelObjects {
            guard string(from: functions.channelGetGroup(channel)) == "Energy Model",
                  let channelName = string(from: functions.channelGetChannelName(channel))
            else {
                continue
            }

            let unitLabel = string(from: functions.channelGetUnitLabel(channel))
            let energyValue = functions.simpleGetIntegerValue(channel, 0)
            let powerWatts = energyToWatts(
                energyValue,
                unitLabel: unitLabel,
                elapsedMilliseconds: elapsedMilliseconds
            )

            switch channelName {
            case "CPU Energy":
                cpuPower += powerWatts
                foundCPUChannel = true
            case "GPU Energy":
                gpuPower += powerWatts
                foundGPUChannel = true
            default:
                if channelName.hasPrefix("ANE") {
                    anePower += powerWatts
                    foundANEChannel = true
                } else if channelName.hasPrefix("DRAM") {
                    dramPower += powerWatts
                    foundDRAMChannel = true
                }
            }
        }

        return EnergyPowerSample(
            cpuPowerWatts: foundCPUChannel ? max(0, cpuPower) : nil,
            gpuPowerWatts: foundGPUChannel ? max(0, gpuPower) : nil,
            dramPowerWatts: foundDRAMChannel ? max(0, dramPower) : nil,
            anePowerWatts: foundANEChannel ? max(0, anePower) : nil
        )
    }

    private func totalSystemPowerWatts() -> Double? {
        if smcReader == nil {
            smcReader = AppleSMCReader()
        }

        guard let value = smcReader?.value(for: "PSTR"), value.isFinite, value >= 0 else {
            return nil
        }

        return value
    }

    private func sumAvailable(_ values: [Double?]) -> Double? {
        var resolvedValues: [Double] = []

        for value in values {
            guard let value else {
                continue
            }

            resolvedValues.append(max(0, value))
        }

        guard !resolvedValues.isEmpty else {
            return nil
        }

        return resolvedValues.reduce(0, +)
    }

    private func energyToWatts(
        _ energyValue: Int64,
        unitLabel: String?,
        elapsedMilliseconds: Double
    ) -> Double {
        let rate = Double(energyValue) / (elapsedMilliseconds / 1000)

        switch normalizedUnitLabel(unitLabel) {
        case "mJ":
            return rate / 1_000
        case "uJ":
            return rate / 1_000_000
        case "nJ":
            return rate / 1_000_000_000
        default:
            return rate / 1_000_000
        }
    }

    private func normalizedUnitLabel(_ label: String?) -> String {
        (label ?? "")
            .components(separatedBy: .whitespaces)
            .first ?? ""
    }

    private func string(from value: Unmanaged<CFString>?) -> String? {
        guard let cfString = value?.takeUnretainedValue() else {
            return nil
        }

        return cfString as String
    }
}

private struct EnergyPowerSample {
    let cpuPowerWatts: Double?
    let gpuPowerWatts: Double?
    let dramPowerWatts: Double?
    let anePowerWatts: Double?

    static let empty = EnergyPowerSample(
        cpuPowerWatts: nil,
        gpuPowerWatts: nil,
        dramPowerWatts: nil,
        anePowerWatts: nil
    )
}

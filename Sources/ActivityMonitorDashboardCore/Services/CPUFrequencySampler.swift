import Foundation
import CoreFoundation
import Darwin
import IOKit

final class CPUFrequencySampler {
    private typealias IOReportSubscriptionRef = OpaquePointer

    private typealias CopyChannelsInGroupFn = @convention(c) (
        CFString,
        CFString?,
        UInt64,
        UInt64,
        UInt64
    ) -> Unmanaged<CFDictionary>?

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

    private typealias ChannelGetGroupFn = @convention(c) (CFDictionary) -> Unmanaged<CFString>?
    private typealias ChannelGetSubGroupFn = @convention(c) (CFDictionary) -> Unmanaged<CFString>?
    private typealias ChannelGetChannelNameFn = @convention(c) (CFDictionary) -> Unmanaged<CFString>?
    private typealias StateGetCountFn = @convention(c) (CFDictionary) -> Int32
    private typealias StateGetNameForIndexFn = @convention(c) (CFDictionary, Int32) -> Unmanaged<CFString>?
    private typealias StateGetResidencyFn = @convention(c) (CFDictionary, Int32) -> Int64

    private final class Functions: @unchecked Sendable {
        let handle: UnsafeMutableRawPointer
        let copyChannelsInGroup: CopyChannelsInGroupFn
        let createSubscription: CreateSubscriptionFn
        let createSamples: CreateSamplesFn
        let createSamplesDelta: CreateSamplesDeltaFn
        let channelGetGroup: ChannelGetGroupFn
        let channelGetSubGroup: ChannelGetSubGroupFn
        let channelGetChannelName: ChannelGetChannelNameFn
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
                let createSubscription = loadSymbol("IOReportCreateSubscription", as: CreateSubscriptionFn.self),
                let createSamples = loadSymbol("IOReportCreateSamples", as: CreateSamplesFn.self),
                let createSamplesDelta = loadSymbol("IOReportCreateSamplesDelta", as: CreateSamplesDeltaFn.self),
                let channelGetGroup = loadSymbol("IOReportChannelGetGroup", as: ChannelGetGroupFn.self),
                let channelGetSubGroup = loadSymbol("IOReportChannelGetSubGroup", as: ChannelGetSubGroupFn.self),
                let channelGetChannelName = loadSymbol("IOReportChannelGetChannelName", as: ChannelGetChannelNameFn.self),
                let stateGetCount = loadSymbol("IOReportStateGetCount", as: StateGetCountFn.self),
                let stateGetNameForIndex = loadSymbol("IOReportStateGetNameForIndex", as: StateGetNameForIndexFn.self),
                let stateGetResidency = loadSymbol("IOReportStateGetResidency", as: StateGetResidencyFn.self)
            else {
                dlclose(handle)
                return nil
            }

            self.handle = handle
            self.copyChannelsInGroup = copyChannelsInGroup
            self.createSubscription = createSubscription
            self.createSamples = createSamples
            self.createSamplesDelta = createSamplesDelta
            self.channelGetGroup = channelGetGroup
            self.channelGetSubGroup = channelGetSubGroup
            self.channelGetChannelName = channelGetChannelName
            self.stateGetCount = stateGetCount
            self.stateGetNameForIndex = stateGetNameForIndex
            self.stateGetResidency = stateGetResidency
        }

        deinit {
            dlclose(handle)
        }
    }

    private struct FrequencyTables {
        let performanceGHz: [Double]
        let superGHz: [Double]
    }

    private struct FrequencyTableCandidate {
        let key: String
        let frequenciesGHz: [Double]
    }

    private static let functions = Functions()

    private let frequencyTables: FrequencyTables
    private var subscription: IOReportSubscriptionRef?
    private var channels: CFMutableDictionary?
    private var previousSample: CFDictionary?

    init() {
        frequencyTables = Self.loadFrequencyTables()
    }

    func sample() -> CPUFrequencySample {
        guard prepareIfNeeded(),
              let functions = Self.functions,
              let subscription,
              let channels,
              !(frequencyTables.performanceGHz.isEmpty && frequencyTables.superGHz.isEmpty),
              let currentSample = functions.createSamples(subscription, channels, nil)?.takeRetainedValue()
        else {
            return .unavailable
        }

        defer {
            previousSample = currentSample
        }

        guard let previousSample,
              let deltaSample = functions.createSamplesDelta(previousSample, currentSample, nil)?.takeRetainedValue()
        else {
            return .unavailable
        }

        return sample(from: deltaSample, using: functions)
    }

    private func prepareIfNeeded() -> Bool {
        guard subscription == nil || channels == nil else {
            return true
        }

        guard let functions = Self.functions,
              let cpuChannels = functions.copyChannelsInGroup(
                "CPU Stats" as CFString,
                "CPU Core Performance States" as CFString,
                0,
                0,
                0
              )?.takeRetainedValue(),
              let mutableChannels = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, cpuChannels)
        else {
            return false
        }

        var subsystem: Unmanaged<CFMutableDictionary>?

        guard let subscription = functions.createSubscription(nil, mutableChannels, &subsystem, 0, nil) else {
            return false
        }

        self.channels = mutableChannels
        self.subscription = subscription
        return true
    }

    private func sample(
        from deltaSample: CFDictionary,
        using functions: Functions
    ) -> CPUFrequencySample {
        guard let channelObjects = (deltaSample as NSDictionary)["IOReportChannels"] as? [Any] else {
            return .unavailable
        }

        var performanceFrequenciesGHz: [Double] = []
        var superFrequenciesGHz: [Double] = []

        for case let channel as CFDictionary in channelObjects {
            guard Self.string(from: functions.channelGetGroup(channel)) == "CPU Stats",
                  Self.string(from: functions.channelGetSubGroup(channel)) == "CPU Core Performance States",
                  let channelName = Self.string(from: functions.channelGetChannelName(channel))
            else {
                continue
            }

            if channelName.hasPrefix("PCPU") {
                if let frequencyGHz = Self.averageFrequency(
                    from: channel,
                    frequenciesGHz: frequencyTables.superGHz,
                    using: functions
                ) {
                    superFrequenciesGHz.append(frequencyGHz)
                }
                continue
            }

            if channelName.hasPrefix("MCPU") || channelName.hasPrefix("ECPU") {
                if let frequencyGHz = Self.averageFrequency(
                    from: channel,
                    frequenciesGHz: frequencyTables.performanceGHz,
                    using: functions
                ) {
                    performanceFrequenciesGHz.append(frequencyGHz)
                }
            }
        }

        let performanceFrequency = Self.average(of: performanceFrequenciesGHz)
        let superFrequency = Self.average(of: superFrequenciesGHz)
        let isAvailable = performanceFrequency != nil || superFrequency != nil

        guard isAvailable else {
            return .unavailable
        }

        return CPUFrequencySample(
            performanceGHz: performanceFrequency ?? 0,
            superGHz: superFrequency ?? 0,
            performanceMaxGHz: frequencyTables.performanceGHz.last ?? performanceFrequency ?? 0,
            superMaxGHz: frequencyTables.superGHz.last ?? superFrequency ?? 0,
            performanceCoreCount: performanceFrequenciesGHz.count,
            superCoreCount: superFrequenciesGHz.count,
            isAvailable: true
        )
    }

    private static func averageFrequency(
        from channel: CFDictionary,
        frequenciesGHz: [Double],
        using functions: Functions
    ) -> Double? {
        guard !frequenciesGHz.isEmpty else {
            return nil
        }

        let stateCount = Int(functions.stateGetCount(channel))
        guard stateCount > 0 else {
            return nil
        }

        var states: [(name: String, residency: Double)] = []

        for index in 0..<stateCount {
            let name = string(from: functions.stateGetNameForIndex(channel, Int32(index))) ?? ""
            let residency = Double(functions.stateGetResidency(channel, Int32(index)))
            states.append((name: name, residency: max(0, residency)))
        }

        guard let offset = states.firstIndex(where: { state in
            let normalizedName = state.name.uppercased()
            return normalizedName != "IDLE" && normalizedName != "DOWN" && normalizedName != "OFF"
        }) else {
            return frequenciesGHz.first
        }

        let activeResidencies = states.dropFirst(offset).map(\.residency)
        let activeResidencyTotal = activeResidencies.reduce(0, +)

        guard activeResidencyTotal > 0 else {
            return frequenciesGHz.first
        }

        let sampleCount = min(activeResidencies.count, frequenciesGHz.count)
        guard sampleCount > 0 else {
            return nil
        }

        var averageGHz = 0.0

        for index in 0..<sampleCount {
            averageGHz += (activeResidencies[index] / activeResidencyTotal) * frequenciesGHz[index]
        }

        return max(averageGHz, frequenciesGHz.first ?? 0)
    }

    private static func loadFrequencyTables() -> FrequencyTables {
        guard let pmgrService = pmgrService() else {
            return FrequencyTables(performanceGHz: [], superGHz: [])
        }

        defer {
            IOObjectRelease(pmgrService)
        }

        let candidates = discoverFrequencyTableCandidates(for: pmgrService)
        let superTable = bestCandidate(
            from: candidates,
            preferredEntryCounts: [20, 19, 18, 17]
        )
        let performanceTable = bestCandidate(
            from: candidates.filter { $0.key != superTable?.key },
            preferredEntryCounts: [15, 16, 14, 13, 12]
        )

        return FrequencyTables(
            performanceGHz: performanceTable?.frequenciesGHz ?? [],
            superGHz: superTable?.frequenciesGHz ?? []
        )
    }

    private static func discoverFrequencyTableCandidates(
        for service: io_registry_entry_t
    ) -> [FrequencyTableCandidate] {
        var candidates: [FrequencyTableCandidate] = []

        for index in 0...31 {
            for suffix in ["-sram", ""] {
                let key = "voltage-states\(index)\(suffix)"

                guard let data = propertyData(named: key, for: service) else {
                    continue
                }

                let frequenciesGHz = parseFrequencies(from: data)

                guard isPlausibleCPUFrequencyTable(frequenciesGHz) else {
                    continue
                }

                candidates.append(
                    FrequencyTableCandidate(
                        key: key,
                        frequenciesGHz: frequenciesGHz
                    )
                )
            }
        }

        return candidates
    }

    private static func bestCandidate(
        from candidates: [FrequencyTableCandidate],
        preferredEntryCounts: [Int]
    ) -> FrequencyTableCandidate? {
        for entryCount in preferredEntryCounts {
            let matches = candidates
                .filter { $0.frequenciesGHz.count == entryCount }
                .sorted { lhs, rhs in
                    let lhsPreference = lhs.key.contains("-sram") ? 1 : 0
                    let rhsPreference = rhs.key.contains("-sram") ? 1 : 0

                    if lhsPreference != rhsPreference {
                        return lhsPreference > rhsPreference
                    }

                    return (lhs.frequenciesGHz.last ?? 0) > (rhs.frequenciesGHz.last ?? 0)
                }

            if let match = matches.first {
                return match
            }
        }

        return candidates.sorted {
            if $0.frequenciesGHz.count != $1.frequenciesGHz.count {
                return $0.frequenciesGHz.count > $1.frequenciesGHz.count
            }

            return ($0.frequenciesGHz.last ?? 0) > ($1.frequenciesGHz.last ?? 0)
        }
        .first
    }

    private static func isPlausibleCPUFrequencyTable(_ frequenciesGHz: [Double]) -> Bool {
        let nonZeroFrequencies = frequenciesGHz.filter { $0 > 0 }

        guard frequenciesGHz.count >= 10,
              let minimum = nonZeroFrequencies.min(),
              let maximum = nonZeroFrequencies.max()
        else {
            return false
        }

        return minimum >= 0.5 && maximum >= 3.0 && maximum <= 6.5
    }

    private static func pmgrService() -> io_registry_entry_t? {
        guard let matchingDictionary = IOServiceMatching("AppleARMIODevice") else {
            return nil
        }

        var iterator: io_iterator_t = .zero
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDictionary, &iterator)

        guard result == KERN_SUCCESS else {
            return nil
        }

        defer {
            IOObjectRelease(iterator)
        }

        while true {
            let service = IOIteratorNext(iterator)

            guard service != 0 else {
                return nil
            }

            if serviceName(for: service) == "pmgr" {
                return service
            }

            IOObjectRelease(service)
        }
    }

    private static func propertyData(
        named key: String,
        for service: io_registry_entry_t
    ) -> Data? {
        IORegistryEntryCreateCFProperty(
            service,
            key as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? Data
    }

    static func parseFrequencies(from data: Data) -> [Double] {
        guard !data.isEmpty else {
            return []
        }

        let itemCount = data.count / 8
        guard itemCount > 0 else {
            return []
        }

        var rawFrequencies: [UInt32] = []
        rawFrequencies.reserveCapacity(itemCount)

        for chunkStart in stride(from: 0, to: itemCount * 8, by: 8) {
            let range = chunkStart..<(chunkStart + 4)
            let rawValue = data.subdata(in: range).withUnsafeBytes { buffer in
                buffer.load(as: UInt32.self)
            }

            rawFrequencies.append(UInt32(littleEndian: rawValue))
        }

        let divisor = scaleDivisor(for: rawFrequencies)

        return rawFrequencies.map { rawFrequency in
            Double(rawFrequency) / divisor / 1_000
        }
    }

    static func scaleDivisor(for rawFrequencies: [UInt32]) -> Double {
        guard let maximum = rawFrequencies.max() else {
            return 1_000
        }

        return maximum > 100_000_000 ? 1_000_000 : 1_000
    }

    private static func average(of values: [Double]) -> Double? {
        guard !values.isEmpty else {
            return nil
        }

        return values.reduce(0, +) / Double(values.count)
    }

    private static func serviceName(for service: io_registry_entry_t) -> String? {
        var nameBuffer = [CChar](repeating: 0, count: 128)
        guard IORegistryEntryGetName(service, &nameBuffer) == KERN_SUCCESS else {
            return nil
        }

        let nameBytes = nameBuffer.prefix { $0 != 0 }.map(UInt8.init)
        return String(decoding: nameBytes, as: UTF8.self)
    }

    private static func string(from value: Unmanaged<CFString>?) -> String? {
        guard let cfString = value?.takeUnretainedValue() else {
            return nil
        }

        return cfString as String
    }
}

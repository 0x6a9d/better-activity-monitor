import Foundation
import IOKit

final class GPUSampler {
    func sample(ioReportReading: IOReportMetricsReading?) -> GPUSample {
        let powerWatts = ioReportReading?.gpuPowerWatts

        if let ioReportSample = sampleFromIOReport(ioReportReading) {
            return ioReportSample
        }

        guard let matchingStatistics = matchingStatistics() else {
            return .unavailable
        }

        var highestUtilization = 0.0

        for statistics in matchingStatistics {
            guard let utilization = utilization(from: statistics) else {
                continue
            }

            if utilization >= highestUtilization {
                highestUtilization = utilization
            }
        }

        guard highestUtilization > 0 || !matchingStatistics.isEmpty else {
            return .unavailable
        }

        let normalizedUtilization = (highestUtilization / 100).clamped(to: 0...1)
        let level = PressureLevel(
            normalizedValue: normalizedUtilization,
            warningThreshold: 0.55,
            criticalThreshold: 0.82
        )

        return GPUSample(
            utilization: normalizedUtilization,
            level: level,
            isAvailable: true,
            powerWatts: powerWatts
        )
    }

    private func sampleFromIOReport(_ ioReportReading: IOReportMetricsReading?) -> GPUSample? {
        guard let utilization = ioReportReading?.gpuUtilization else {
            return nil
        }

        let level = PressureLevel(
            normalizedValue: utilization,
            warningThreshold: 0.55,
            criticalThreshold: 0.82
        )

        return GPUSample(
            utilization: utilization,
            level: level,
            isAvailable: true,
            powerWatts: ioReportReading?.gpuPowerWatts
        )
    }

    private func matchingStatistics() -> [[String: Any]]? {
        guard let matchingDictionary = IOServiceMatching("IOAccelerator") else {
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

        var matches: [[String: Any]] = []

        while true {
            let service = IOIteratorNext(iterator)

            guard service != 0 else {
                break
            }

            defer {
                IOObjectRelease(service)
            }

            guard let statistics = property(named: "PerformanceStatistics", for: service) as? [String: Any] else {
                continue
            }

            matches.append(statistics)
        }

        return matches
    }

    private func utilization(from statistics: [String: Any]) -> Double? {
        let keys = [
            "Device Utilization %",
            "Renderer Utilization %",
            "GPU Activity(%)",
        ]

        for key in keys {
            if let numericValue = statistics[key] as? NSNumber {
                return numericValue.doubleValue
            }

            if let stringValue = statistics[key] as? String,
               let parsedValue = Double(stringValue)
            {
                return parsedValue
            }
        }

        return nil
    }
    private func property(named key: String, for service: io_registry_entry_t) -> Any? {
        let directProperty = IORegistryEntryCreateCFProperty(
            service,
            key as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue()

        if let directProperty {
            return directProperty
        }

        return IORegistryEntrySearchCFProperty(
            service,
            kIOServicePlane,
            key as CFString,
            kCFAllocatorDefault,
            IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents)
        )
    }
}

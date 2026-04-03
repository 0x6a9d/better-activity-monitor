import Foundation

final class ANESampler {
    private let estimatedMaximumPowerWatts = 8.0

    func sample(ioReportReading: IOReportMetricsReading?) -> ANESample {
        guard let powerWatts = ioReportReading?.anePowerWatts else {
            return .unavailable
        }

        let normalizedUtilization = (powerWatts / estimatedMaximumPowerWatts).clamped(to: 0...1)
        let level = PressureLevel(
            normalizedValue: normalizedUtilization,
            warningThreshold: 0.55,
            criticalThreshold: 0.82
        )

        return ANESample(
            utilization: normalizedUtilization,
            powerWatts: powerWatts,
            level: level,
            isAvailable: true
        )
    }
}

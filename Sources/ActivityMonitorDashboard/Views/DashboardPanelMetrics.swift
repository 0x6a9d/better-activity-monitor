import SwiftUI
import ActivityMonitorDashboardCore

extension DashboardView {
    func averagePower(in samples: [TotalPowerSample]) -> Double? {
        guard !samples.isEmpty else {
            return nil
        }

        return samples.map(\.watts).reduce(0, +) / Double(samples.count)
    }

    func powerUsagePercent(for currentWatts: Double) -> Double {
        let displayMaximum = max(
            10,
            (viewModel.totalPowerSamples.map(\.watts).max() ?? 0) * 1.15
        )

        guard displayMaximum > 0 else {
            return 0
        }

        return (currentWatts / displayMaximum).clamped(to: 0...1)
    }

    var averageCPUUsageText: String {
        average(in: viewModel.cpuSamples.map(\.totalUsage))
            .map { MetricFormatting.percent($0) } ?? "--"
    }

    var averageCPUFrequencyText: String {
        average(in: viewModel.cpuFrequencySamples.filter(\.isAvailable).map(\.overallGHz))
            .map { MetricFormatting.gigahertz($0) } ?? "--"
    }

    var averageMemoryPressureText: String {
        average(in: viewModel.memorySamples.map(\.pressure))
            .map { MetricFormatting.percent($0) } ?? "--"
    }

    var averageGPUUsageText: String {
        average(in: viewModel.gpuSamples.filter(\.isAvailable).map(\.utilization))
            .map { MetricFormatting.percent($0) } ?? "--"
    }

    var averageANEUsageText: String {
        average(in: viewModel.aneSamples.filter(\.isAvailable).map(\.utilization))
            .map { MetricFormatting.percent($0) } ?? "--"
    }

    var averageThermalTemperatureText: String {
        average(in: viewModel.thermalSamples.compactMap(\.displayTemperatureCelsius))
            .map(MetricFormatting.temperature) ?? "--"
    }

    var averageFanSpeedText: String {
        average(in: viewModel.thermalSamples.compactMap(\.fanSpeedRPM))
            .map(MetricFormatting.rpm) ?? "--"
    }

    func average(in values: [Double]) -> Double? {
        guard !values.isEmpty else {
            return nil
        }

        return values.reduce(0, +) / Double(values.count)
    }

    func fanSpeedHeadline(fan1: FanReading?, fan2: FanReading?, in sample: ThermalSample) -> Text {
        (
            Text("Fan 1: ")
                .foregroundColor(.secondary)
            + Text(fanPercentText(for: fan1, in: sample))
                .foregroundColor(fanPercentColor(for: fan1, in: sample))
            + Text(" / Fan 2: ")
                .foregroundColor(.secondary)
            + Text(fanPercentText(for: fan2, in: sample))
                .foregroundColor(fanPercentColor(for: fan2, in: sample))
        )
        .font(.title3.weight(.semibold))
    }

    func fanPercentText(for fan: FanReading?, in sample: ThermalSample) -> String {
        guard let percent = fanPercentValue(for: fan, in: sample) else {
            return "--"
        }

        return MetricFormatting.percent(percent)
    }

    func fanPercentValue(for fan: FanReading?, in sample: ThermalSample) -> Double? {
        guard let fan else {
            return nil
        }

        if let maximumRPM = fan.maximumRPM, maximumRPM > 0 {
            return (fan.currentRPM / maximumRPM).clamped(to: 0...1)
        }

        if let fallbackMaximumRPM = sample.maximumFanRPM, fallbackMaximumRPM > 0 {
            return (fan.currentRPM / fallbackMaximumRPM).clamped(to: 0...1)
        }

        return nil
    }

    func fanPercentColor(for fan: FanReading?, in sample: ThermalSample) -> Color {
        guard let percent = fanPercentValue(for: fan, in: sample) else {
            return DashboardPalette.secondaryLabel
        }

        switch percent {
        case 0.82...:
            return DashboardPalette.heavy
        case 0.55...:
            return DashboardPalette.moderate
        default:
            return DashboardPalette.good
        }
    }

    func maxFanSpeedText(for sample: ThermalSample) -> String {
        guard let maximumFanRPM = sample.maximumFanRPM else {
            return "--"
        }

        return MetricFormatting.rpm(maximumFanRPM)
    }

    @ViewBuilder
    func fanMaxSpeedFooter(for sample: ThermalSample) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(maxFanSpeedText(for: sample))
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(.primary)

            Text("Max Fan Speed")
                .font(.caption)
                .foregroundStyle(DashboardPalette.secondaryLabel)
        }
        .multilineTextAlignment(.trailing)
    }
}

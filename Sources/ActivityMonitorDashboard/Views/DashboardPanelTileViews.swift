import SwiftUI
import ActivityMonitorDashboardCore

struct PanelGraphContent<Graph: View>: View {
    let isEditingDashboard: Bool
    let swatches: [PanelEditSwatch]
    let graph: Graph

    var body: some View {
        ZStack(alignment: .top) {
            graph

            if isEditingDashboard {
                PanelSwatchRow(swatches: swatches)
                    .padding(.top, 8)
            }
        }
    }
}

struct CPULoadPanelTile: View {
    @ObservedObject var model: CPULoadPanelModel
    let graphStyle: GraphStyle
    let userColor: Color
    let systemColor: Color
    let swatches: [PanelEditSwatch]
    let isEditingDashboard: Bool

    var body: some View {
        let state = model.state
        let stats = [
            MetricStat(label: "System", value: MetricFormatting.percent(state.latestSample.systemUsage), valueColor: systemColor),
            MetricStat(label: "User", value: MetricFormatting.percent(state.latestSample.userUsage), valueColor: userColor),
            MetricStat(label: "Temp", value: state.cpuTemperatureCelsius.map(MetricFormatting.temperature) ?? "--"),
            MetricStat(label: "Power", value: state.latestSample.powerWatts.map { MetricFormatting.watts($0) } ?? "--"),
            MetricStat(label: "Average", value: state.averageUsage.map { MetricFormatting.percent($0) } ?? "--"),
        ]

        MetricPanelView(
            title: "CPU Load",
            headline: MetricFormatting.percent(state.latestSample.totalUsage),
            accentColor: userColor,
            stats: stats
        ) {
            PanelGraphContent(
                isEditingDashboard: isEditingDashboard,
                swatches: swatches,
                graph: CPULoadHistogramView(
                    samples: state.samples,
                    capacity: DashboardViewModel.historyCapacity,
                    style: graphStyle,
                    userColor: userColor,
                    systemColor: systemColor
                )
                .equatable()
            )
        } footer: {
            ProcessLeaderFooter(leader: state.leader, style: .stacked)
        }
    }
}

struct CPUFrequencyPanelTile: View {
    @ObservedObject var model: CPUFrequencyPanelModel
    let graphStyle: GraphStyle
    let performanceColor: Color
    let superColor: Color
    let swatches: [PanelEditSwatch]
    let isEditingDashboard: Bool

    var body: some View {
        let state = model.state
        let sample = state.latestSample
        let stats = [
            MetricStat(
                label: "Performance",
                value: sample.isAvailable ? MetricFormatting.gigahertz(sample.performanceGHz) : "--",
                valueColor: performanceColor
            ),
            MetricStat(
                label: "Super",
                value: sample.isAvailable ? MetricFormatting.gigahertz(sample.superGHz) : "--",
                valueColor: superColor
            ),
            MetricStat(
                label: "Average",
                value: state.averageGHz.map { MetricFormatting.gigahertz($0) } ?? "--"
            ),
        ]

        MetricPanelView(
            title: "CPU Frequency",
            headline: sample.isAvailable ? MetricFormatting.gigahertz(sample.overallGHz) : "Unavailable",
            accentColor: performanceColor,
            stats: stats
        ) {
            PanelGraphContent(
                isEditingDashboard: isEditingDashboard,
                swatches: swatches,
                graph: CPUFrequencyHistogramView(
                    samples: state.samples,
                    capacity: DashboardViewModel.historyCapacity,
                    style: graphStyle,
                    performanceColor: performanceColor,
                    superColor: superColor
                )
                .equatable()
            )
        } footer: {
            EmptyView()
        }
    }
}

struct MemoryPressurePanelTile: View {
    @ObservedObject var model: MemoryPressurePanelModel
    let graphStyle: GraphStyle
    let colors: PressureGraphColors
    let swatches: [PanelEditSwatch]
    let isEditingDashboard: Bool

    var body: some View {
        let state = model.state
        let sample = state.latestSample
        let accentColor = colors.color(for: sample.level)
        let stats = [
            MetricStat(label: "Usage", value: MetricFormatting.bytes(sample.usedBytes)),
            MetricStat(label: "Temp", value: state.socTemperatureCelsius.map(MetricFormatting.temperature) ?? "--"),
            MetricStat(label: "Power", value: sample.powerWatts.map { MetricFormatting.watts($0) } ?? "--"),
            MetricStat(
                label: "Average",
                value: state.averagePressure.map { MetricFormatting.percent($0) } ?? "--",
                valueColor: accentColor
            ),
        ]

        MetricPanelView(
            title: "Memory Pressure",
            headline: MetricFormatting.percent(sample.pressure),
            accentColor: accentColor,
            stats: stats
        ) {
            PanelGraphContent(
                isEditingDashboard: isEditingDashboard,
                swatches: swatches,
                graph: PressureHistogramView(
                    samples: state.histogramSamples,
                    capacity: DashboardViewModel.historyCapacity,
                    isUnavailable: false,
                    style: graphStyle,
                    palette: colors,
                    colorOverride: nil
                )
                .equatable()
            )
        } footer: {
            ProcessLeaderFooter(leader: state.leader, style: .stacked)
        }
    }
}

struct GPUPressurePanelTile: View {
    @ObservedObject var model: GPUPressurePanelModel
    let graphStyle: GraphStyle
    let colors: PressureGraphColors
    let swatches: [PanelEditSwatch]
    let isEditingDashboard: Bool

    var body: some View {
        let state = model.state
        let sample = state.latestSample
        let accentColor = colors.color(for: sample.level)
        let stats = [
            MetricStat(label: "Temp", value: state.gpuTemperatureCelsius.map(MetricFormatting.temperature) ?? "--"),
            MetricStat(label: "Power", value: sample.powerWatts.map { MetricFormatting.watts($0) } ?? "--"),
            MetricStat(
                label: "Average",
                value: state.averageUsage.map { MetricFormatting.percent($0) } ?? "--",
                valueColor: accentColor
            ),
        ]

        MetricPanelView(
            title: "GPU Pressure",
            headline: sample.isAvailable ? MetricFormatting.percent(sample.utilization) : "Unavailable",
            accentColor: accentColor,
            stats: stats
        ) {
            PanelGraphContent(
                isEditingDashboard: isEditingDashboard,
                swatches: swatches,
                graph: PressureHistogramView(
                    samples: state.histogramSamples,
                    capacity: DashboardViewModel.historyCapacity,
                    isUnavailable: !sample.isAvailable,
                    style: graphStyle,
                    palette: colors,
                    colorOverride: nil
                )
                .equatable()
            )
        } footer: {
            ProcessLeaderFooter(leader: state.leader, style: .stacked)
        }
    }
}

struct ANEUsagePanelTile: View {
    @ObservedObject var model: ANEUsagePanelModel
    let graphStyle: GraphStyle
    let color: Color
    let swatches: [PanelEditSwatch]
    let isEditingDashboard: Bool

    var body: some View {
        let state = model.state
        let sample = state.latestSample
        let stats = [
            MetricStat(label: "Temp", value: state.socTemperatureCelsius.map(MetricFormatting.temperature) ?? "--"),
            MetricStat(label: "Power", value: sample.isAvailable ? MetricFormatting.watts(sample.powerWatts) : "--"),
            MetricStat(
                label: "Average",
                value: state.averageUsage.map { MetricFormatting.percent($0) } ?? "--"
            ),
        ]

        MetricPanelView(
            title: "ANE Usage",
            headline: sample.isAvailable ? MetricFormatting.percent(sample.utilization) : "Unavailable",
            accentColor: color,
            stats: stats
        ) {
            PanelGraphContent(
                isEditingDashboard: isEditingDashboard,
                swatches: swatches,
                graph: PressureHistogramView(
                    samples: state.histogramSamples,
                    capacity: DashboardViewModel.historyCapacity,
                    isUnavailable: !sample.isAvailable,
                    style: graphStyle,
                    palette: nil,
                    colorOverride: color
                )
                .equatable()
            )
        } footer: {
            EmptyView()
        }
    }
}

struct TotalPowerPanelTile: View {
    @ObservedObject var model: TotalPowerPanelModel
    let graphStyle: GraphStyle
    let color: Color
    let swatches: [PanelEditSwatch]
    let isEditingDashboard: Bool

    var body: some View {
        let state = model.state
        let stats = [
            MetricStat(
                label: "Total",
                value: state.currentWatts.map {
                    MetricFormatting.watts(
                        $0,
                        minimumFractionDigits: 2,
                        maximumFractionDigits: 2,
                        includeSpace: false
                    )
                } ?? "--",
                valueColor: color
            ),
            MetricStat(
                label: "Average",
                value: state.averageWatts.map {
                    MetricFormatting.watts(
                        $0,
                        minimumFractionDigits: 2,
                        maximumFractionDigits: 2,
                        includeSpace: false
                    )
                } ?? "--",
                valueColor: color
            ),
        ]
        let headline = state.currentWatts.map {
            MetricFormatting.percent(($0 / state.displayMaximumWatts).clamped(to: 0...1))
        } ?? "Unavailable"

        MetricPanelView(
            title: "Total Power Usage",
            headline: headline,
            accentColor: color,
            stats: stats
        ) {
            PanelGraphContent(
                isEditingDashboard: isEditingDashboard,
                swatches: swatches,
                graph: PowerHistogramView(
                    samples: state.samples,
                    capacity: DashboardViewModel.historyCapacity,
                    style: graphStyle,
                    color: color
                )
                .equatable()
            )
        } footer: {
            EmptyView()
        }
    }
}

struct ThermalStatePanelTile: View {
    @ObservedObject var model: ThermalStatePanelModel
    let graphStyle: GraphStyle
    let colors: PressureGraphColors
    let swatches: [PanelEditSwatch]
    let isEditingDashboard: Bool

    var body: some View {
        let state = model.state
        let sample = state.latestSample
        let color = colors.color(for: sample.thermalState)
        let stats = [
            MetricStat(label: "State", value: sample.thermalState.title, valueColor: color),
            MetricStat(
                label: "Average",
                value: state.averageTemperatureCelsius.map(MetricFormatting.temperature) ?? "--",
                valueColor: color
            ),
        ]

        MetricPanelView(
            title: "Thermal State",
            headline: sample.displayTemperatureCelsius.map(MetricFormatting.temperature) ?? "Unavailable",
            accentColor: color,
            stats: stats
        ) {
            PanelGraphContent(
                isEditingDashboard: isEditingDashboard,
                swatches: swatches,
                graph: ThermalStateHistogramView(
                    samples: state.samples,
                    capacity: DashboardViewModel.historyCapacity,
                    style: graphStyle,
                    palette: colors
                )
                .equatable()
            )
        } footer: {
            EmptyView()
        }
    }
}

struct FanSpeedPanelTile: View {
    @ObservedObject var model: FanSpeedPanelModel
    let graphStyle: GraphStyle
    let fan1Color: Color
    let fan2Color: Color
    let swatches: [PanelEditSwatch]
    let isEditingDashboard: Bool

    var body: some View {
        let state = model.state
        let sample = state.latestSample
        let fan1 = sample.fan(number: 1)
        let fan2 = sample.fan(number: 2)
        let stats = [
            MetricStat(label: "Fan 1", value: fan1.map { MetricFormatting.rpm($0.currentRPM) } ?? "--", valueColor: fan1Color),
            MetricStat(label: "Fan 2", value: fan2.map { MetricFormatting.rpm($0.currentRPM) } ?? "--", valueColor: fan2Color),
            MetricStat(label: "Average", value: state.averageFanSpeedRPM.map(MetricFormatting.rpm) ?? "--"),
        ]

        MetricPanelView(
            title: "Fan Speed",
            accentColor: DashboardPalette.label,
            stats: stats,
            headline: {
                fanSpeedHeadline(fan1: fan1, fan2: fan2, in: sample)
            },
            content: {
                PanelGraphContent(
                    isEditingDashboard: isEditingDashboard,
                    swatches: swatches,
                    graph: FanSpeedHistogramView(
                        samples: state.samples,
                        capacity: DashboardViewModel.historyCapacity,
                        style: graphStyle,
                        fan1Color: fan1Color,
                        fan2Color: fan2Color
                    )
                    .equatable()
                )
            },
            footer: {
                fanMaxSpeedFooter(for: sample)
            }
        )
    }
}

@MainActor
private func fanSpeedHeadline(
    fan1: FanReading?,
    fan2: FanReading?,
    in sample: ThermalSample
) -> Text {
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

@MainActor
private func fanPercentText(for fan: FanReading?, in sample: ThermalSample) -> String {
    guard let percent = fanPercentValue(for: fan, in: sample) else {
        return "--"
    }

    return MetricFormatting.percent(percent)
}

@MainActor
private func fanPercentValue(for fan: FanReading?, in sample: ThermalSample) -> Double? {
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

@MainActor
private func fanPercentColor(for fan: FanReading?, in sample: ThermalSample) -> Color {
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

@MainActor
private func fanMaxSpeedFooter(for sample: ThermalSample) -> some View {
    VStack(alignment: .trailing, spacing: 2) {
        Text(sample.maximumFanRPM.map(MetricFormatting.rpm) ?? "--")
            .font(.subheadline.monospacedDigit().weight(.semibold))
            .foregroundStyle(.primary)

        Text("Max Fan Speed")
            .font(.caption)
            .foregroundStyle(DashboardPalette.secondaryLabel)
    }
    .multilineTextAlignment(.trailing)
}

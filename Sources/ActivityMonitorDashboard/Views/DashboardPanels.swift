import SwiftUI
import ActivityMonitorDashboardCore

extension DashboardView {
    var customization: DashboardCustomization {
        customizationStore.customization
    }

    @ViewBuilder
    func panelView(for panel: DashboardPanelKind) -> some View {
        switch panel {
        case .cpuLoad:
            cpuPanel
        case .cpuFrequency:
            cpuFrequencyPanel
        case .gpuPressure:
            gpuPanel
        case .memoryPressure:
            memoryPanel
        case .aneUsage:
            anePanel
        case .totalPowerUsage:
            totalPowerPanel
        case .thermalState:
            thermalPanel
        case .fanSpeed:
            fanSpeedPanel
        }
    }

    func pressureColor(for level: PressureLevel, colors: PressureGraphColors) -> Color {
        colors.color(for: level)
    }

    func thermalStateColor(for state: ThermalStateStatus) -> Color {
        customization.thermalStateColors.color(for: state)
    }

    var cpuPanel: some View {
        let sample = viewModel.latestCPU ?? CPUSample(userUsage: 0, systemUsage: 0, idleUsage: 1)
        let stats = [
            MetricStat(
                label: "System",
                value: MetricFormatting.percent(sample.systemUsage),
                valueColor: customization.cpuSystemColor
            ),
            MetricStat(
                label: "User",
                value: MetricFormatting.percent(sample.userUsage),
                valueColor: customization.cpuUserColor
            ),
            MetricStat(
                label: "Temp",
                value: viewModel.thermalSample.cpuTemperatureCelsius.map(MetricFormatting.temperature) ?? "--"
            ),
            MetricStat(
                label: "Power",
                value: sample.powerWatts.map { MetricFormatting.watts($0) } ?? "--"
            ),
            MetricStat(
                label: "Average",
                value: averageCPUUsageText,
                valueColor: .primary
            ),
        ]

        return MetricPanelView(
            title: "CPU Load",
            headline: MetricFormatting.percent(sample.totalUsage),
            accentColor: customization.cpuUserColor,
            stats: stats
        ) {
            panelContent(for: .cpuLoad) {
                CPULoadHistogramView(
                    samples: viewModel.cpuSamples,
                    capacity: DashboardViewModel.historyCapacity,
                    style: graphStyle,
                    userColor: customization.cpuUserColor,
                    systemColor: customization.cpuSystemColor
                )
            }
        } footer: {
            ProcessLeaderFooter(leader: viewModel.processLeaders.cpu, style: .stacked)
        }
    }

    var cpuFrequencyPanel: some View {
        let sample = viewModel.latestCPUFrequency ?? .unavailable
        let stats = [
            MetricStat(
                label: "Performance",
                value: sample.isAvailable ? MetricFormatting.gigahertz(sample.performanceGHz) : "--",
                valueColor: customization.cpuFrequencyPerformanceColor
            ),
            MetricStat(
                label: "Super",
                value: sample.isAvailable ? MetricFormatting.gigahertz(sample.superGHz) : "--",
                valueColor: customization.cpuFrequencySuperColor
            ),
            MetricStat(
                label: "Average",
                value: averageCPUFrequencyText,
                valueColor: .primary
            ),
        ]

        return MetricPanelView(
            title: "CPU Frequency",
            headline: sample.isAvailable ? MetricFormatting.gigahertz(sample.overallGHz) : "Unavailable",
            accentColor: customization.cpuFrequencyPerformanceColor,
            stats: stats
        ) {
            panelContent(for: .cpuFrequency) {
                CPUFrequencyHistogramView(
                    samples: viewModel.cpuFrequencySamples,
                    capacity: DashboardViewModel.historyCapacity,
                    style: graphStyle,
                    performanceColor: customization.cpuFrequencyPerformanceColor,
                    superColor: customization.cpuFrequencySuperColor
                )
            }
        } footer: {
            EmptyView()
        }
    }

    var memoryPanel: some View {
        let colors = customization.memoryPressureColors
        let sample = viewModel.latestMemory ?? MemorySample(
            pressure: 0,
            level: .good,
            usedBytes: 0,
            cachedBytes: 0,
            compressedBytes: 0,
            freeBytes: 0,
            physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory
        )
        let stats = [
            MetricStat(label: "Usage", value: MetricFormatting.bytes(sample.usedBytes)),
            MetricStat(
                label: "Temp",
                value: viewModel.thermalSample.socTemperatureCelsius.map(MetricFormatting.temperature) ?? "--"
            ),
            MetricStat(
                label: "Power",
                value: sample.powerWatts.map { MetricFormatting.watts($0) } ?? "--"
            ),
            MetricStat(
                label: "Average",
                value: averageMemoryPressureText,
                valueColor: pressureColor(for: sample.level, colors: colors)
            ),
        ]

        return MetricPanelView(
            title: "Memory Pressure",
            headline: MetricFormatting.percent(sample.pressure),
            accentColor: pressureColor(for: sample.level, colors: colors),
            stats: stats
        ) {
            panelContent(for: .memoryPressure) {
                PressureHistogramView(
                    samples: viewModel.memorySamples.map(\.histogramSample),
                    capacity: DashboardViewModel.historyCapacity,
                    isUnavailable: false,
                    style: graphStyle,
                    palette: colors,
                    colorOverride: nil
                )
            }
        } footer: {
            ProcessLeaderFooter(leader: viewModel.processLeaders.memory, style: .stacked)
        }
    }

    var gpuPanel: some View {
        let colors = customization.gpuPressureColors
        let sample = viewModel.latestGPU ?? .unavailable
        let stats = [
            MetricStat(
                label: "Temp",
                value: viewModel.thermalSample.gpuTemperatureCelsius.map(MetricFormatting.temperature) ?? "--"
            ),
            MetricStat(
                label: "Power",
                value: sample.powerWatts.map { MetricFormatting.watts($0) } ?? "--"
            ),
            MetricStat(
                label: "Average",
                value: averageGPUUsageText,
                valueColor: pressureColor(for: sample.level, colors: colors)
            ),
        ]

        return MetricPanelView(
            title: "GPU Pressure",
            headline: sample.isAvailable ? MetricFormatting.percent(sample.utilization) : "Unavailable",
            accentColor: pressureColor(for: sample.level, colors: colors),
            stats: stats
        ) {
            panelContent(for: .gpuPressure) {
                PressureHistogramView(
                    samples: viewModel.gpuSamples.map(\.histogramSample),
                    capacity: DashboardViewModel.historyCapacity,
                    isUnavailable: !sample.isAvailable,
                    style: graphStyle,
                    palette: colors,
                    colorOverride: nil
                )
            }
        } footer: {
            ProcessLeaderFooter(leader: viewModel.processLeaders.gpu, style: .stacked)
        }
    }

    var anePanel: some View {
        let sample = viewModel.latestANE ?? .unavailable
        let stats = [
            MetricStat(
                label: "Temp",
                value: viewModel.thermalSample.socTemperatureCelsius.map(MetricFormatting.temperature) ?? "--"
            ),
            MetricStat(
                label: "Power",
                value: sample.isAvailable ? MetricFormatting.watts(sample.powerWatts) : "--"
            ),
            MetricStat(
                label: "Average",
                value: averageANEUsageText,
                valueColor: customization.aneColor
            ),
        ]

        return MetricPanelView(
            title: "ANE Usage",
            headline: sample.isAvailable ? MetricFormatting.percent(sample.utilization) : "Unavailable",
            accentColor: customization.aneColor,
            stats: stats
        ) {
            panelContent(for: .aneUsage) {
                PressureHistogramView(
                    samples: viewModel.aneSamples.map(\.histogramSample),
                    capacity: DashboardViewModel.historyCapacity,
                    isUnavailable: !sample.isAvailable,
                    style: graphStyle,
                    palette: nil,
                    colorOverride: customization.aneColor
                )
            }
        } footer: {
            EmptyView()
        }
    }

    var totalPowerPanel: some View {
        let sample = viewModel.latestTotalPower
        let averagePowerWatts = averagePower(in: viewModel.totalPowerSamples)
        let currentPowerWatts = sample?.watts
        let stats = [
            MetricStat(
                label: "Total",
                value: currentPowerWatts.map {
                    MetricFormatting.watts(
                        $0,
                        minimumFractionDigits: 2,
                        maximumFractionDigits: 2,
                        includeSpace: false
                    )
                } ?? "--",
                valueColor: customization.totalPowerColor
            ),
            MetricStat(
                label: "Average",
                value: averagePowerWatts.map {
                    MetricFormatting.watts(
                        $0,
                        minimumFractionDigits: 2,
                        maximumFractionDigits: 2,
                        includeSpace: false
                    )
                } ?? "--",
                valueColor: customization.totalPowerColor
            ),
        ]

        return MetricPanelView(
            title: "Total Power Usage",
            headline: currentPowerWatts.map { MetricFormatting.percent(powerUsagePercent(for: $0)) } ?? "Unavailable",
            accentColor: customization.totalPowerColor,
            stats: stats
        ) {
            panelContent(for: .totalPowerUsage) {
                PowerHistogramView(
                    samples: viewModel.totalPowerSamples,
                    capacity: DashboardViewModel.historyCapacity,
                    style: graphStyle,
                    color: customization.totalPowerColor
                )
            }
        } footer: {
            EmptyView()
        }
    }

    var thermalPanel: some View {
        let sample = viewModel.thermalSample
        let color = thermalStateColor(for: sample.thermalState)
        let stats = [
            MetricStat(label: "State", value: sample.thermalState.title, valueColor: color),
            MetricStat(label: "Average", value: averageThermalTemperatureText, valueColor: color),
        ]

        return MetricPanelView(
            title: "Thermal State",
            headline: sample.displayTemperatureCelsius.map(MetricFormatting.temperature) ?? "Unavailable",
            accentColor: color,
            stats: stats
        ) {
            panelContent(for: .thermalState) {
                ThermalStateHistogramView(
                    samples: viewModel.thermalSamples,
                    capacity: DashboardViewModel.historyCapacity,
                    style: graphStyle,
                    palette: customization.thermalStateColors
                )
            }
        } footer: {
            EmptyView()
        }
    }

    var fanSpeedPanel: some View {
        let sample = viewModel.thermalSample
        let fan1 = sample.fan(number: 1)
        let fan2 = sample.fan(number: 2)
        let stats = [
            MetricStat(
                label: "Fan 1",
                value: fan1.map { MetricFormatting.rpm($0.currentRPM) } ?? "--",
                valueColor: customization.fan1Color
            ),
            MetricStat(
                label: "Fan 2",
                value: fan2.map { MetricFormatting.rpm($0.currentRPM) } ?? "--",
                valueColor: customization.fan2Color
            ),
            MetricStat(
                label: "Average",
                value: averageFanSpeedText,
                valueColor: .primary
            ),
        ]

        return MetricPanelView(
            title: "Fan Speed",
            accentColor: DashboardPalette.label,
            stats: stats,
            headline: {
                fanSpeedHeadline(fan1: fan1, fan2: fan2, in: sample)
            },
            content: {
                panelContent(for: .fanSpeed) {
                    FanSpeedHistogramView(
                        samples: viewModel.thermalSamples,
                        capacity: DashboardViewModel.historyCapacity,
                        style: graphStyle,
                        fan1Color: customization.fan1Color,
                        fan2Color: customization.fan2Color
                    )
                }
            },
            footer: {
                fanMaxSpeedFooter(for: sample)
            }
        )
    }
}

struct ProcessLeaderFooter: View {
    let leader: ProcessLeader?
    let style: ProcessLeaderFooterStyle

    init(leader: ProcessLeader?, style: ProcessLeaderFooterStyle = .inline) {
        self.leader = leader
        self.style = style
    }

    var body: some View {
        Group {
            if let leader {
                switch style {
                case .inline:
                    Text("\(leader.name) \(leader.displayValue)")
                        .font(.caption.monospacedDigit())
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(DashboardPalette.secondaryLabel)

                case .stacked:
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(leader.displayValue)
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(leader.name)
                            .font(.caption)
                            .foregroundStyle(DashboardPalette.secondaryLabel)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .multilineTextAlignment(.trailing)
                }
            } else {
                Text("Sampling process usage...")
                    .font(.caption)
                    .foregroundStyle(DashboardPalette.secondaryLabel)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}

enum ProcessLeaderFooterStyle {
    case inline
    case stacked
}

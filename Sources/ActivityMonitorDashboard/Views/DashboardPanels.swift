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
            CPULoadPanelTile(
                model: viewModel.cpuLoadPanel,
                graphStyle: graphStyle,
                userColor: customization.cpuUserColor,
                systemColor: customization.cpuSystemColor,
                swatches: panelSwatches(for: .cpuLoad),
                isEditingDashboard: isEditingDashboard
            )
        case .cpuFrequency:
            CPUFrequencyPanelTile(
                model: viewModel.cpuFrequencyPanel,
                graphStyle: graphStyle,
                performanceColor: customization.cpuFrequencyPerformanceColor,
                superColor: customization.cpuFrequencySuperColor,
                swatches: panelSwatches(for: .cpuFrequency),
                isEditingDashboard: isEditingDashboard
            )
        case .gpuPressure:
            GPUPressurePanelTile(
                model: viewModel.gpuPressurePanel,
                graphStyle: graphStyle,
                colors: customization.gpuPressureColors,
                swatches: panelSwatches(for: .gpuPressure),
                isEditingDashboard: isEditingDashboard
            )
        case .memoryPressure:
            MemoryPressurePanelTile(
                model: viewModel.memoryPressurePanel,
                graphStyle: graphStyle,
                colors: customization.memoryPressureColors,
                swatches: panelSwatches(for: .memoryPressure),
                isEditingDashboard: isEditingDashboard
            )
        case .aneUsage:
            ANEUsagePanelTile(
                model: viewModel.aneUsagePanel,
                graphStyle: graphStyle,
                color: customization.aneColor,
                swatches: panelSwatches(for: .aneUsage),
                isEditingDashboard: isEditingDashboard
            )
        case .totalPowerUsage:
            TotalPowerPanelTile(
                model: viewModel.totalPowerPanel,
                graphStyle: graphStyle,
                color: customization.totalPowerColor,
                swatches: panelSwatches(for: .totalPowerUsage),
                isEditingDashboard: isEditingDashboard
            )
        case .thermalState:
            ThermalStatePanelTile(
                model: viewModel.thermalStatePanel,
                graphStyle: graphStyle,
                colors: customization.thermalStateColors,
                swatches: panelSwatches(for: .thermalState),
                isEditingDashboard: isEditingDashboard
            )
        case .fanSpeed:
            FanSpeedPanelTile(
                model: viewModel.fanSpeedPanel,
                graphStyle: graphStyle,
                fan1Color: customization.fan1Color,
                fan2Color: customization.fan2Color,
                swatches: panelSwatches(for: .fanSpeed),
                isEditingDashboard: isEditingDashboard
            )
        }
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

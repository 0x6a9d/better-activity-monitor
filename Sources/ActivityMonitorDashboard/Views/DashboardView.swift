import SwiftUI
import ActivityMonitorDashboardCore

struct DashboardView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject var viewModel = DashboardViewModel()
    @StateObject var customizationStore = DashboardCustomizationStore()
    @AppStorage("graphStyle") var graphStyleRawValue = GraphStyle.filledLine.rawValue
    @AppStorage("appearanceMode") var appearanceModeRawValue = AppearanceMode.auto.rawValue
    @State var isEditingDashboard = false
    @State var draggedPanel: DashboardPanelKind?
    @State var dropTargetPanel: DashboardPanelKind?

    let panelIdealWidth: CGFloat = 348

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            controls
            dashboardGrid
        }
        .padding(16)
        .background(DashboardPalette.windowBackground.ignoresSafeArea())
        .onAppear {
            syncSamplingState()
        }
        .onChange(of: isEditingDashboard) { _, isEditing in
            if !isEditing {
                resetDragPreview()
            }
            syncSamplingState()
        }
        .onChange(of: scenePhase) { _, _ in
            syncSamplingState()
        }
        .onDisappear {
            resetDragPreview()
            viewModel.stop()
        }
        .animation(.easeInOut(duration: 0.18), value: isEditingDashboard)
    }

    var graphStyle: GraphStyle {
        GraphStyle(rawValue: graphStyleRawValue) ?? .filledLine
    }

    var appearanceMode: AppearanceMode {
        AppearanceMode.fromStoredValue(appearanceModeRawValue)
    }

    var shouldSampleMetrics: Bool {
        scenePhase == .active && !isEditingDashboard
    }

    func syncSamplingState() {
        if shouldSampleMetrics {
            viewModel.start()
        } else {
            viewModel.stop()
        }
    }

    func updateDropPreview(for targetPanel: DashboardPanelKind, isTargeted: Bool) {
        guard isEditingDashboard else {
            return
        }

        if isTargeted,
           let draggedPanel,
           draggedPanel != targetPanel
        {
            dropTargetPanel = targetPanel
            return
        }

        if dropTargetPanel == targetPanel {
            dropTargetPanel = nil
        }
    }

    func resetDragPreview() {
        draggedPanel = nil
        dropTargetPanel = nil
    }

    var controls: some View {
        HStack {
            Spacer(minLength: 12)

            HStack(spacing: 8) {
                Picker(
                    "",
                    selection: Binding(
                        get: { appearanceMode },
                        set: { appearanceModeRawValue = $0.rawValue }
                    )
                ) {
                    ForEach(AppearanceMode.allCases) { mode in
                        appearanceModeLabel(for: mode).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 144)

                Picker(
                    "",
                    selection: Binding(
                        get: { graphStyle },
                        set: { graphStyleRawValue = $0.rawValue }
                    )
                ) {
                    ForEach(GraphStyle.allCases) { style in
                        graphStyleIcon(for: style).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 96)

                Button {
                    if isEditingDashboard {
                        resetDragPreview()
                    }

                    isEditingDashboard.toggle()
                } label: {
                    Group {
                        if isEditingDashboard {
                            Text("Done")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                        } else {
                            Image(systemName: "gearshape")
                                .font(.subheadline.weight(.semibold))
                                .frame(width: 40)
                        }
                    }
                    .frame(height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(DashboardPalette.segmentedControlBackground)
                    )
                }
                .buttonStyle(.plain)
                .help(isEditingDashboard ? "Finish customizing the dashboard" : "Customize graph colors and layout")
            }
        }
    }

    var dashboardGrid: some View {
        VStack(spacing: 12) {
            ForEach(Array(customizationStore.customization.panelRows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 12) {
                    ForEach(row) { panel in
                        dashboardTile(for: panel)
                    }

                    if row.count < 2 {
                        Spacer(minLength: panelIdealWidth)
                    }
                }
            }
        }
    }

    func graphStyleIcon(for style: GraphStyle) -> Image {
        switch style {
        case .bars:
            Image(systemName: "chart.bar.xaxis")
        case .filledLine:
            Image(systemName: "chart.line.uptrend.xyaxis")
        }
    }

    @ViewBuilder
    func appearanceModeLabel(for mode: AppearanceMode) -> some View {
        switch mode {
        case .auto:
            Text("Auto")
                .font(.subheadline.weight(.medium))
        case .light, .dark:
            Image(systemName: mode.symbolName)
                .accessibilityLabel(Text(mode.rawValue))
        }
    }
}

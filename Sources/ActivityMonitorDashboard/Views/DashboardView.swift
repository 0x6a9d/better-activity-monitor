import AppKit
import SwiftUI
import ActivityMonitorDashboardCore

struct DashboardView: View {
    @StateObject var viewModel = DashboardViewModel()
    @StateObject var customizationStore = DashboardCustomizationStore()
    @StateObject private var hardwareProfileStore = SystemHardwareProfileStore()
    @AppStorage("graphStyle") var graphStyleRawValue = GraphStyle.filledLine.rawValue
    @AppStorage("appearanceMode") var appearanceModeRawValue = AppearanceMode.auto.rawValue
    @AppStorage(AppPreferenceKey.showMenuBarIcon) private var showMenuBarIcon = true
    @AppStorage(AppPreferenceKey.showDockIcon) private var showDockIcon = true
    @State var isEditingDashboard = false
    @State var isAppActive = NSApp.isActive
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
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            isAppActive = true
            syncSamplingState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            isAppActive = false
            syncSamplingState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openDashboardSettings)) { _ in
            openSettings()
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

    var samplingMode: DashboardViewModel.SamplingMode {
        if isEditingDashboard {
            return .paused
        }

        return isAppActive ? .foreground : .background
    }

    func syncSamplingState() {
        viewModel.setSamplingMode(samplingMode)
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

    func toggleSettings() {
        if isEditingDashboard {
            resetDragPreview()
        }

        isEditingDashboard.toggle()
    }

    func openSettings() {
        guard !isEditingDashboard else {
            restoreDashboardFocus()
            return
        }

        isEditingDashboard = true
    }

    func restoreDashboardFocus() {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            let activeWindow = NSApp.keyWindow
                ?? NSApp.mainWindow
                ?? NSApp.windows.first(where: { $0.isVisible })
            activeWindow?.makeKeyAndOrderFront(nil)
        }
    }

    var hardwareProfile: SystemHardwareProfile {
        hardwareProfileStore.profile
    }

    var controls: some View {
        HStack(alignment: .top, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                chipLabel

                visibilityControls
                    .opacity(isEditingDashboard ? 1 : 0)
                    .allowsHitTesting(isEditingDashboard)
                    .accessibilityHidden(!isEditingDashboard)
            }

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
                    toggleSettings()
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
                .help(isEditingDashboard ? "Close settings" : "Open settings and customize the dashboard")
            }
        }
        .frame(minHeight: 48, alignment: .top)
    }

    var visibilityControls: some View {
        HStack(spacing: 14) {
            Toggle("Menubar", isOn: menuBarIconBinding)
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(showMenuBarIcon && !showDockIcon)

            Toggle("Dock", isOn: dockIconBinding)
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(showDockIcon && !showMenuBarIcon)
        }
        .font(.caption.weight(.medium))
        .fixedSize()
    }

    var chipLabel: some View {
        Text(hardwareProfile.chipDisplayName)
            .font(.headline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(DashboardPalette.segmentedControlBackground)
            )
            .fixedSize()
    }

    var menuBarIconBinding: Binding<Bool> {
        Binding(
            get: { showMenuBarIcon },
            set: { newValue in
                showMenuBarIcon = newValue
                restoreDashboardFocus()
            }
        )
    }

    var dockIconBinding: Binding<Bool> {
        Binding(
            get: { showDockIcon },
            set: { newValue in
                showDockIcon = newValue
                restoreDashboardFocus()
            }
        )
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

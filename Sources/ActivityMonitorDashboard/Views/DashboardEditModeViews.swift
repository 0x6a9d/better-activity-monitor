import SwiftUI

struct PanelEditSwatch: Identifiable {
    let id: String
    let label: String
    let selection: Binding<Color>
}

struct PanelSwatchRow: View {
    let swatches: [PanelEditSwatch]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(swatches) { swatch in
                VStack(spacing: 4) {
                    ColorPicker("", selection: swatch.selection, supportsOpacity: false)
                        .labelsHidden()
                        .scaleEffect(0.92)

                    Text(swatch.label)
                        .font(.caption2)
                        .foregroundStyle(DashboardPalette.secondaryLabel)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(maxWidth: 64)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(DashboardPalette.windowBackground.opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(DashboardPalette.panelBorder.opacity(0.6), lineWidth: 1)
        )
    }
}

struct WiggleModifier: ViewModifier {
    let isActive: Bool
    let phaseOffset: Double

    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isActive ? (isAnimating ? 0.9 : -0.9) : 0))
            .offset(y: isActive ? (isAnimating ? 0.8 : -0.8) : 0)
            .animation(
                isActive
                ? .easeInOut(duration: 0.15).repeatForever(autoreverses: true).delay(phaseOffset)
                : .easeOut(duration: 0.12),
                value: isAnimating
            )
            .onAppear {
                syncAnimationState()
            }
            .onChange(of: isActive) { _, _ in
                syncAnimationState()
            }
    }

    private func syncAnimationState() {
        if isActive {
            isAnimating = true
        } else {
            isAnimating = false
        }
    }
}

extension View {
    func tileWiggle(active: Bool, phaseOffset: Double) -> some View {
        modifier(WiggleModifier(isActive: active, phaseOffset: phaseOffset))
    }
}

extension DashboardView {
    @ViewBuilder
    func dashboardTile(for panel: DashboardPanelKind) -> some View {
        let baseTile = panelView(for: panel)
            .frame(
                minWidth: panelIdealWidth,
                idealWidth: panelIdealWidth,
                maxWidth: .infinity,
                alignment: .topLeading
            )

        if isEditingDashboard {
            let panelIndex = customization.panelOrder.firstIndex(of: panel) ?? 0

            baseTile
                .tileWiggle(active: true, phaseOffset: Double(panelIndex) * 0.015)
                .scaleEffect(draggedPanel == panel ? 1.02 : 1)
                .shadow(color: .black.opacity(draggedPanel == panel ? 0.16 : 0.08), radius: draggedPanel == panel ? 12 : 5, y: draggedPanel == panel ? 8 : 3)
                .zIndex(draggedPanel == panel ? 5 : 0)
                .onDrag {
                    draggedPanel = panel
                    return NSItemProvider(object: panel.rawValue as NSString)
                }
                .dropDestination(for: String.self) { items, _ in
                    handleTileDrop(items: items, targetPanel: panel)
                } isTargeted: { _ in
                }
        } else {
            baseTile
        }
    }

    @ViewBuilder
    func panelContent<Graph: View>(for panel: DashboardPanelKind, @ViewBuilder graph: () -> Graph) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if isEditingDashboard {
                PanelSwatchRow(swatches: panelSwatches(for: panel))
            }

            graph()
        }
    }

    func handleTileDrop(items: [String], targetPanel: DashboardPanelKind) -> Bool {
        defer {
            draggedPanel = nil
        }

        guard let rawValue = items.first,
              let panel = DashboardPanelKind(rawValue: rawValue),
              let targetIndex = customization.panelOrder.firstIndex(of: targetPanel)
        else {
            return false
        }

        customizationStore.move(panel, to: targetIndex)
        return true
    }

    func panelSwatches(for panel: DashboardPanelKind) -> [PanelEditSwatch] {
        switch panel {
        case .cpuLoad:
            [
                PanelEditSwatch(id: "cpu-system", label: "System", selection: customizationStore.binding(for: \.cpuSystem)),
                PanelEditSwatch(id: "cpu-user", label: "User", selection: customizationStore.binding(for: \.cpuUser)),
            ]

        case .cpuFrequency:
            [
                PanelEditSwatch(id: "cpu-performance", label: "Performance", selection: customizationStore.binding(for: \.cpuFrequencyPerformance)),
                PanelEditSwatch(id: "cpu-super", label: "Super", selection: customizationStore.binding(for: \.cpuFrequencySuper)),
            ]

        case .gpuPressure:
            [
                PanelEditSwatch(id: "gpu-good", label: "Good", selection: customizationStore.binding(for: \.gpuGood)),
                PanelEditSwatch(id: "gpu-moderate", label: "Moderate", selection: customizationStore.binding(for: \.gpuModerate)),
                PanelEditSwatch(id: "gpu-heavy", label: "Heavy", selection: customizationStore.binding(for: \.gpuHeavy)),
            ]

        case .memoryPressure:
            [
                PanelEditSwatch(id: "memory-good", label: "Good", selection: customizationStore.binding(for: \.memoryGood)),
                PanelEditSwatch(id: "memory-moderate", label: "Moderate", selection: customizationStore.binding(for: \.memoryModerate)),
                PanelEditSwatch(id: "memory-heavy", label: "Heavy", selection: customizationStore.binding(for: \.memoryHeavy)),
            ]

        case .aneUsage:
            [
                PanelEditSwatch(id: "ane", label: "Usage", selection: customizationStore.binding(for: \.ane)),
            ]

        case .totalPowerUsage:
            [
                PanelEditSwatch(id: "total-power", label: "Usage", selection: customizationStore.binding(for: \.totalPower)),
            ]

        case .thermalState:
            [
                PanelEditSwatch(id: "thermal-normal", label: "Normal", selection: customizationStore.binding(for: \.thermalGood)),
                PanelEditSwatch(id: "thermal-serious", label: "Serious", selection: customizationStore.binding(for: \.thermalModerate)),
                PanelEditSwatch(id: "thermal-critical", label: "Critical", selection: customizationStore.binding(for: \.thermalHeavy)),
            ]

        case .fanSpeed:
            [
                PanelEditSwatch(id: "fan-1", label: "Fan 1", selection: customizationStore.binding(for: \.fan1)),
                PanelEditSwatch(id: "fan-2", label: "Fan 2", selection: customizationStore.binding(for: \.fan2)),
            ]
        }
    }
}

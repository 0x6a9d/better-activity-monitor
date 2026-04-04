import SwiftUI

struct PanelEditSwatch: Identifiable {
    let id: String
    let label: String
    let selection: Binding<Color>
    let defaultColor: Color
}

struct PanelSwatchRow: View {
    let swatches: [PanelEditSwatch]
    @State private var presentedSwatchID: String?

    var body: some View {
        HStack(spacing: 8) {
            ForEach(swatches) { swatch in
                PanelSwatchChip(
                    swatch: swatch,
                    isPalettePresented: presentedBinding(for: swatch.id)
                )
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(DashboardPalette.panelBorder.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
    }

    private func presentedBinding(for swatchID: String) -> Binding<Bool> {
        Binding(
            get: { presentedSwatchID == swatchID },
            set: { isPresented in
                presentedSwatchID = isPresented ? swatchID : nil
            }
        )
    }
}

struct PanelSwatchChip: View {
    let swatch: PanelEditSwatch
    @Binding var isPalettePresented: Bool

    var body: some View {
        Button {
            isPalettePresented.toggle()
        } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(swatch.selection.wrappedValue)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.8), lineWidth: 1)
                    )

                Text(swatch.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(DashboardPalette.secondaryLabel)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(DashboardPalette.panelBackground.opacity(isPalettePresented ? 0.95 : 0.68))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(
                        isPalettePresented ? Color.accentColor.opacity(0.55) : DashboardPalette.panelBorder.opacity(0.5),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPalettePresented, arrowEdge: .top) {
            PanelColorPalette(
                title: swatch.label,
                selection: swatch.selection,
                defaultColor: swatch.defaultColor,
                isPresented: $isPalettePresented
            )
        }
    }
}

struct PanelColorPalette: View {
    let title: String
    let selection: Binding<Color>
    let defaultColor: Color
    @Binding var isPresented: Bool

    private let columns = Array(
        repeating: GridItem(.fixed(24), spacing: 8),
        count: DashboardPalette.quickColorPresetColumns
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                selection.wrappedValue = defaultColor
                isPresented = false
            } label: {
                Text("Reset")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .disabled(matchesSelected(defaultColor))
            .opacity(matchesSelected(defaultColor) ? 0.45 : 1)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DashboardPalette.secondaryLabel)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(DashboardPalette.quickColorPresets.enumerated()), id: \.offset) { _, color in
                    Button {
                        selection.wrappedValue = color
                        isPresented = false
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle()
                                    .stroke(DashboardPalette.panelBorder.opacity(0.8), lineWidth: 1)
                            )
                            .overlay {
                                if matchesSelected(color) {
                                    Circle()
                                        .stroke(Color.primary, lineWidth: 2)
                                        .padding(-3)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(DashboardPalette.windowBackground)
    }

    private func matchesSelected(_ color: Color) -> Bool {
        PersistedColor(selection.wrappedValue) == PersistedColor(color)
    }
}

struct EditModeHandle: View {
    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(.title.weight(.bold))
            .foregroundStyle(.primary)
            .frame(width: 68, height: 68)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(DashboardPalette.panelBorder.opacity(0.75), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

extension DashboardView {
    func editModeTilt(for panelIndex: Int) -> Double {
        panelIndex.isMultiple(of: 2) ? -0.35 : 0.35
    }

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
            let isDropTarget = dropTargetPanel == panel && draggedPanel != panel

            baseTile
                .rotationEffect(.degrees(draggedPanel == panel ? 0 : editModeTilt(for: panelIndex)))
                .scaleEffect(draggedPanel == panel ? 1.02 : 1)
                .shadow(color: .black.opacity(draggedPanel == panel ? 0.16 : 0.08), radius: draggedPanel == panel ? 12 : 5, y: draggedPanel == panel ? 8 : 3)
                .overlay {
                    if isDropTarget {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.accentColor.opacity(0.8), lineWidth: 3)
                            .padding(1)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    EditModeHandle()
                        .padding(10)
                }
                .zIndex(draggedPanel == panel ? 5 : 0)
                .onDrag {
                    draggedPanel = panel
                    return NSItemProvider(object: panel.rawValue as NSString)
                }
                .dropDestination(for: String.self) { items, _ in
                    handleTileDrop(items: items, targetPanel: panel)
                } isTargeted: { isTargeted in
                    updateDropPreview(for: panel, isTargeted: isTargeted)
                }
        } else {
            baseTile
        }
    }

    @ViewBuilder
    func panelContent<Graph: View>(for panel: DashboardPanelKind, @ViewBuilder graph: () -> Graph) -> some View {
        ZStack(alignment: .top) {
            graph()

            if isEditingDashboard {
                PanelSwatchRow(swatches: panelSwatches(for: panel))
                    .padding(.top, 8)
            }
        }
    }

    func handleTileDrop(items: [String], targetPanel: DashboardPanelKind) -> Bool {
        defer {
            resetDragPreview()
        }

        guard let rawValue = items.first,
              let panel = DashboardPanelKind(rawValue: rawValue)
        else {
            return false
        }

        customizationStore.swap(panel, with: targetPanel)
        return true
    }

    func panelSwatches(for panel: DashboardPanelKind) -> [PanelEditSwatch] {
        switch panel {
        case .cpuLoad:
            [
                panelSwatch(id: "cpu-system", label: "System", keyPath: \.cpuSystem),
                panelSwatch(id: "cpu-user", label: "User", keyPath: \.cpuUser),
            ]

        case .cpuFrequency:
            [
                panelSwatch(id: "cpu-performance", label: "Performance", keyPath: \.cpuFrequencyPerformance),
                panelSwatch(id: "cpu-super", label: "Super", keyPath: \.cpuFrequencySuper),
            ]

        case .gpuPressure:
            [
                panelSwatch(id: "gpu-good", label: "Good", keyPath: \.gpuGood),
                panelSwatch(id: "gpu-moderate", label: "Moderate", keyPath: \.gpuModerate),
                panelSwatch(id: "gpu-heavy", label: "Heavy", keyPath: \.gpuHeavy),
            ]

        case .memoryPressure:
            [
                panelSwatch(id: "memory-good", label: "Good", keyPath: \.memoryGood),
                panelSwatch(id: "memory-moderate", label: "Moderate", keyPath: \.memoryModerate),
                panelSwatch(id: "memory-heavy", label: "Heavy", keyPath: \.memoryHeavy),
            ]

        case .aneUsage:
            [
                panelSwatch(id: "ane", label: "Usage", keyPath: \.ane),
            ]

        case .totalPowerUsage:
            [
                panelSwatch(id: "total-power", label: "Usage", keyPath: \.totalPower),
            ]

        case .thermalState:
            [
                panelSwatch(id: "thermal-normal", label: "Normal", keyPath: \.thermalGood),
                panelSwatch(id: "thermal-serious", label: "Serious", keyPath: \.thermalModerate),
                panelSwatch(id: "thermal-critical", label: "Critical", keyPath: \.thermalHeavy),
            ]

        case .fanSpeed:
            [
                panelSwatch(id: "fan-1", label: "Fan 1", keyPath: \.fan1),
                panelSwatch(id: "fan-2", label: "Fan 2", keyPath: \.fan2),
            ]
        }
    }

    func panelSwatch(
        id: String,
        label: String,
        keyPath: WritableKeyPath<DashboardCustomization, PersistedColor>
    ) -> PanelEditSwatch {
        PanelEditSwatch(
            id: id,
            label: label,
            selection: customizationStore.binding(for: keyPath),
            defaultColor: customizationStore.defaultColor(for: keyPath)
        )
    }
}

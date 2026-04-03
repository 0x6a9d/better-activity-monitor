import SwiftUI
import AppKit
import ActivityMonitorDashboardCore

enum DashboardPanelKind: String, CaseIterable, Codable, Identifiable {
    case cpuLoad
    case cpuFrequency
    case gpuPressure
    case memoryPressure
    case aneUsage
    case totalPowerUsage
    case thermalState
    case fanSpeed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cpuLoad:
            "CPU Load"
        case .cpuFrequency:
            "CPU Frequency"
        case .gpuPressure:
            "GPU Pressure"
        case .memoryPressure:
            "Memory Pressure"
        case .aneUsage:
            "ANE Usage"
        case .totalPowerUsage:
            "Total Power Usage"
        case .thermalState:
            "Thermal State"
        case .fanSpeed:
            "Fan Speed"
        }
    }
}

struct PersistedColor: Codable, Equatable {
    let red: Double
    let green: Double
    let blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = red.clamped(to: 0...1)
        self.green = green.clamped(to: 0...1)
        self.blue = blue.clamped(to: 0...1)
    }

    init(_ color: Color) {
        let resolved = NSColor(color).usingColorSpace(.deviceRGB) ?? .white
        self.init(
            red: Double(resolved.redComponent),
            green: Double(resolved.greenComponent),
            blue: Double(resolved.blueComponent)
        )
    }

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }
}

struct PressureGraphColors: Equatable {
    let good: Color
    let moderate: Color
    let heavy: Color

    func color(for level: PressureLevel) -> Color {
        switch level {
        case .good:
            good
        case .moderate:
            moderate
        case .heavy:
            heavy
        }
    }

    func color(for thermalState: ThermalStateStatus) -> Color {
        switch thermalState {
        case .normal, .fair:
            good
        case .serious:
            moderate
        case .critical:
            heavy
        case .unknown:
            DashboardPalette.secondaryLabel
        }
    }
}

struct DashboardCustomization: Codable, Equatable {
    var panelOrder: [DashboardPanelKind] = [
        .cpuLoad,
        .cpuFrequency,
        .gpuPressure,
        .memoryPressure,
        .aneUsage,
        .totalPowerUsage,
        .thermalState,
        .fanSpeed,
    ]

    var cpuUser = PersistedColor(red: 0.30, green: 0.61, blue: 0.96)
    var cpuSystem = PersistedColor(red: 0.94, green: 0.40, blue: 0.31)
    var cpuFrequencyPerformance = PersistedColor(red: 0.22, green: 0.82, blue: 0.95)
    var cpuFrequencySuper = PersistedColor(red: 0.96, green: 0.57, blue: 0.21)

    var gpuGood = PersistedColor(red: 0.30, green: 0.76, blue: 0.35)
    var gpuModerate = PersistedColor(red: 0.93, green: 0.73, blue: 0.18)
    var gpuHeavy = PersistedColor(red: 0.88, green: 0.28, blue: 0.24)

    var memoryGood = PersistedColor(red: 0.30, green: 0.76, blue: 0.35)
    var memoryModerate = PersistedColor(red: 0.93, green: 0.73, blue: 0.18)
    var memoryHeavy = PersistedColor(red: 0.88, green: 0.28, blue: 0.24)

    var ane = PersistedColor(red: 0.58, green: 0.36, blue: 0.93)
    var totalPower = PersistedColor(red: 0.93, green: 0.61, blue: 0.18)

    var thermalGood = PersistedColor(red: 0.30, green: 0.76, blue: 0.35)
    var thermalModerate = PersistedColor(red: 0.93, green: 0.73, blue: 0.18)
    var thermalHeavy = PersistedColor(red: 0.88, green: 0.28, blue: 0.24)

    var fan1 = PersistedColor(red: 0.14, green: 0.78, blue: 0.67)
    var fan2 = PersistedColor(red: 0.96, green: 0.36, blue: 0.72)

    mutating func normalizePanelOrder() {
        var normalized = panelOrder.filter { DashboardPanelKind.allCases.contains($0) }

        for panel in DashboardPanelKind.allCases where !normalized.contains(panel) {
            normalized.append(panel)
        }

        panelOrder = normalized
    }

    mutating func resetColors() {
        let defaults = DashboardCustomization()
        cpuUser = defaults.cpuUser
        cpuSystem = defaults.cpuSystem
        cpuFrequencyPerformance = defaults.cpuFrequencyPerformance
        cpuFrequencySuper = defaults.cpuFrequencySuper
        gpuGood = defaults.gpuGood
        gpuModerate = defaults.gpuModerate
        gpuHeavy = defaults.gpuHeavy
        memoryGood = defaults.memoryGood
        memoryModerate = defaults.memoryModerate
        memoryHeavy = defaults.memoryHeavy
        ane = defaults.ane
        totalPower = defaults.totalPower
        thermalGood = defaults.thermalGood
        thermalModerate = defaults.thermalModerate
        thermalHeavy = defaults.thermalHeavy
        fan1 = defaults.fan1
        fan2 = defaults.fan2
    }

    mutating func resetLayout() {
        panelOrder = DashboardCustomization().panelOrder
    }

    var cpuUserColor: Color { cpuUser.color }
    var cpuSystemColor: Color { cpuSystem.color }
    var cpuFrequencyPerformanceColor: Color { cpuFrequencyPerformance.color }
    var cpuFrequencySuperColor: Color { cpuFrequencySuper.color }
    var aneColor: Color { ane.color }
    var totalPowerColor: Color { totalPower.color }
    var fan1Color: Color { fan1.color }
    var fan2Color: Color { fan2.color }

    var gpuPressureColors: PressureGraphColors {
        PressureGraphColors(good: gpuGood.color, moderate: gpuModerate.color, heavy: gpuHeavy.color)
    }

    var memoryPressureColors: PressureGraphColors {
        PressureGraphColors(good: memoryGood.color, moderate: memoryModerate.color, heavy: memoryHeavy.color)
    }

    var thermalStateColors: PressureGraphColors {
        PressureGraphColors(good: thermalGood.color, moderate: thermalModerate.color, heavy: thermalHeavy.color)
    }

    var panelRows: [[DashboardPanelKind]] {
        stride(from: 0, to: panelOrder.count, by: 2).map { index in
            Array(panelOrder[index..<min(index + 2, panelOrder.count)])
        }
    }
}

@MainActor
final class DashboardCustomizationStore: ObservableObject {
    private static let storageKey = "dashboardCustomization"

    @Published private(set) var customization: DashboardCustomization

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        if let storedValue = userDefaults.string(forKey: Self.storageKey),
           let data = storedValue.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(DashboardCustomization.self, from: data) {
            var normalized = decoded
            normalized.normalizePanelOrder()
            customization = normalized
        } else {
            customization = DashboardCustomization()
        }
    }

    func move(_ panel: DashboardPanelKind, by offset: Int) {
        guard let currentIndex = customization.panelOrder.firstIndex(of: panel) else {
            return
        }

        let newIndex = currentIndex + offset
        guard customization.panelOrder.indices.contains(newIndex) else {
            return
        }

        var updated = customization
        updated.panelOrder.swapAt(currentIndex, newIndex)
        apply(updated)
    }

    func move(_ panel: DashboardPanelKind, to targetIndex: Int) {
        guard let currentIndex = customization.panelOrder.firstIndex(of: panel),
              customization.panelOrder.indices.contains(targetIndex),
              currentIndex != targetIndex
        else {
            return
        }

        var updated = customization
        let panel = updated.panelOrder.remove(at: currentIndex)
        let adjustedTargetIndex = currentIndex < targetIndex ? targetIndex - 1 : targetIndex
        updated.panelOrder.insert(panel, at: adjustedTargetIndex)
        apply(updated)
    }

    func resetColors() {
        var updated = customization
        updated.resetColors()
        apply(updated)
    }

    func resetLayout() {
        var updated = customization
        updated.resetLayout()
        apply(updated)
    }

    func binding(for keyPath: WritableKeyPath<DashboardCustomization, PersistedColor>) -> Binding<Color> {
        Binding(
            get: { self.customization[keyPath: keyPath].color },
            set: { newColor in
                var updated = self.customization
                updated[keyPath: keyPath] = PersistedColor(newColor)
                self.apply(updated)
            }
        )
    }

    private func apply(_ customization: DashboardCustomization) {
        var normalized = customization
        normalized.normalizePanelOrder()
        self.customization = normalized
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(customization),
              let encoded = String(data: data, encoding: .utf8)
        else {
            return
        }

        userDefaults.set(encoded, forKey: Self.storageKey)
    }
}

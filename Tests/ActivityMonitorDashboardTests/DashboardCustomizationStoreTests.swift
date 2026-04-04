import Foundation
import Testing
@testable import ActivityMonitorDashboard

@MainActor
@Test
func swappingPanelsKeepsAllOtherTilesInPlace() {
    let suiteName = "DashboardCustomizationStoreTests.\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    let store = DashboardCustomizationStore(userDefaults: userDefaults)

    store.swap(.cpuLoad, with: .aneUsage)

    #expect(
        store.customization.panelOrder == [
            .aneUsage,
            .cpuFrequency,
            .gpuPressure,
            .memoryPressure,
            .cpuLoad,
            .totalPowerUsage,
            .thermalState,
            .fanSpeed,
        ]
    )
}

@MainActor
@Test
func swappingAdjacentPanelsExchangesTheirPositions() {
    let suiteName = "DashboardCustomizationStoreTests.\(UUID().uuidString)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    let store = DashboardCustomizationStore(userDefaults: userDefaults)

    store.swap(.cpuLoad, with: .cpuFrequency)

    #expect(
        store.customization.panelOrder == [
            .cpuFrequency,
            .cpuLoad,
            .gpuPressure,
            .memoryPressure,
            .aneUsage,
            .totalPowerUsage,
            .thermalState,
            .fanSpeed,
        ]
    )
}

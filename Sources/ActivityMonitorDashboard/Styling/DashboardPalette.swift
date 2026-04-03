import SwiftUI
import ActivityMonitorDashboardCore

enum DashboardPalette {
    static let windowBackground = Color(nsColor: .windowBackgroundColor)
    static let panelBackground = Color(nsColor: .controlBackgroundColor)
    static let segmentedControlBackground = Color(nsColor: .quaternaryLabelColor).opacity(0.5)
    static let panelBorder = Color(nsColor: .separatorColor).opacity(0.35)
    static let grid = Color(nsColor: .separatorColor).opacity(0.14)
    static let label = Color.primary
    static let secondaryLabel = Color.secondary
    static let cpuUser = Color(red: 0.30, green: 0.61, blue: 0.96)
    static let cpuSystem = Color(red: 0.94, green: 0.40, blue: 0.31)
    static let cpuFrequencyPerformance = Color(red: 0.22, green: 0.82, blue: 0.95)
    static let cpuFrequencySuper = Color(red: 0.96, green: 0.57, blue: 0.21)
    static let ane = Color(red: 0.58, green: 0.36, blue: 0.93)
    static let totalPower = Color(red: 0.93, green: 0.61, blue: 0.18)
    static let fan1 = Color(red: 0.14, green: 0.78, blue: 0.67)
    static let fan2 = Color(red: 0.96, green: 0.36, blue: 0.72)
    static let good = Color(red: 0.30, green: 0.76, blue: 0.35)
    static let moderate = Color(red: 0.93, green: 0.73, blue: 0.18)
    static let heavy = Color(red: 0.88, green: 0.28, blue: 0.24)
}

extension PressureLevel {
    var histogramColor: Color {
        switch self {
        case .good:
            DashboardPalette.good
        case .moderate:
            DashboardPalette.moderate
        case .heavy:
            DashboardPalette.heavy
        }
    }
}

extension ThermalStateStatus {
    var histogramColor: Color {
        switch self {
        case .normal, .fair:
            DashboardPalette.good
        case .serious:
            DashboardPalette.moderate
        case .critical:
            DashboardPalette.heavy
        case .unknown:
            DashboardPalette.secondaryLabel
        }
    }
}

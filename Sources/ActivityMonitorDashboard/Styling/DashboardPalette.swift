import SwiftUI
import ActivityMonitorDashboardCore

enum DashboardPalette {
    private static func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
        Color(red: red / 255, green: green / 255, blue: blue / 255)
    }

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
    static let quickColorPresetColumns = 10
    static let quickColorPresets: [Color] = [
        rgb(0, 0, 0),
        rgb(67, 67, 67),
        rgb(102, 102, 102),
        rgb(153, 153, 153),
        rgb(183, 183, 183),
        rgb(204, 204, 204),
        rgb(217, 217, 217),
        rgb(239, 239, 239),
        rgb(243, 243, 243),
        rgb(255, 255, 255),

        rgb(152, 0, 0),
        rgb(255, 0, 0),
        rgb(255, 153, 0),
        rgb(255, 255, 0),
        rgb(0, 255, 0),
        rgb(0, 255, 255),
        rgb(77, 156, 245),
        rgb(0, 0, 255),
        rgb(153, 0, 255),
        rgb(255, 0, 255),

        rgb(230, 184, 175),
        rgb(244, 204, 204),
        rgb(252, 229, 205),
        rgb(255, 242, 204),
        rgb(217, 234, 211),
        rgb(208, 224, 227),
        rgb(201, 218, 248),
        rgb(207, 226, 243),
        rgb(217, 210, 233),
        rgb(234, 209, 220),

        rgb(221, 126, 107),
        rgb(234, 153, 153),
        rgb(249, 203, 156),
        rgb(255, 229, 153),
        rgb(182, 215, 168),
        rgb(162, 196, 201),
        rgb(164, 194, 244),
        rgb(159, 197, 232),
        rgb(180, 167, 214),
        rgb(213, 166, 189),

        rgb(204, 65, 37),
        rgb(224, 102, 102),
        rgb(246, 178, 107),
        rgb(255, 217, 102),
        rgb(147, 196, 125),
        rgb(118, 165, 175),
        rgb(109, 158, 235),
        rgb(111, 168, 220),
        rgb(142, 124, 195),
        rgb(194, 123, 160),

        rgb(166, 28, 0),
        rgb(204, 0, 0),
        rgb(230, 145, 56),
        rgb(241, 194, 50),
        rgb(106, 168, 79),
        rgb(69, 129, 142),
        rgb(61, 133, 198),
        rgb(60, 120, 216),
        rgb(103, 78, 167),
        rgb(166, 77, 121),

        rgb(133, 32, 12),
        rgb(153, 0, 0),
        rgb(180, 95, 6),
        rgb(191, 144, 0),
        rgb(56, 118, 29),
        rgb(19, 79, 92),
        rgb(17, 85, 204),
        rgb(11, 83, 148),
        rgb(53, 28, 117),
        rgb(116, 27, 71),

        rgb(91, 15, 0),
        rgb(102, 0, 0),
        rgb(120, 63, 4),
        rgb(127, 96, 0),
        rgb(39, 78, 19),
        rgb(12, 52, 61),
        rgb(28, 69, 135),
        rgb(7, 55, 99),
        rgb(32, 18, 77),
        rgb(76, 17, 48),
    ]
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

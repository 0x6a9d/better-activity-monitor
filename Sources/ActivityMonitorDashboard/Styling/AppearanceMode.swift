import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

enum AppearanceMode: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case light = "Light"
    case dark = "Dark"

    var id: String {
        rawValue
    }

    var symbolName: String {
        switch self {
        case .auto:
            "desktopcomputer"
        case .light:
            "sun.max.fill"
        case .dark:
            "moon.fill"
        }
    }

    static func fromStoredValue(_ storedValue: String) -> AppearanceMode {
        switch storedValue {
        case AppearanceMode.auto.rawValue, "System":
            .auto
        case AppearanceMode.light.rawValue:
            .light
        case AppearanceMode.dark.rawValue:
            .dark
        default:
            .auto
        }
    }

    #if canImport(AppKit)
    @MainActor
    func applyToApplication() {
        let appearance: NSAppearance?

        switch self {
        case .auto:
            appearance = nil
        case .light:
            appearance = NSAppearance(named: .aqua)
        case .dark:
            appearance = NSAppearance(named: .darkAqua)
        }

        NSApp.appearance = appearance
        NSApp.windows.forEach { $0.appearance = appearance }
    }
    #endif
}

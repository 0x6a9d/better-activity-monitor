import AppKit

enum AppPreferenceKey {
    static let appearanceMode = "appearanceMode"
    static let showMenuBarIcon = "showMenuBarIcon"
    static let showDockIcon = "showDockIcon"
}

struct AppVisibilityPreferences: Equatable {
    static let defaultValues: [String: Bool] = [
        AppPreferenceKey.showMenuBarIcon: true,
        AppPreferenceKey.showDockIcon: true,
    ]

    let showsMenuBarIcon: Bool
    let showsDockIcon: Bool

    var normalized: AppVisibilityPreferences {
        guard showsMenuBarIcon || showsDockIcon else {
            return AppVisibilityPreferences(
                showsMenuBarIcon: true,
                showsDockIcon: false
            )
        }

        return self
    }

    var activationPolicy: NSApplication.ActivationPolicy {
        showsDockIcon ? .regular : .accessory
    }

    var shouldStayRunningAfterLastWindowCloses: Bool {
        showsMenuBarIcon || showsDockIcon
    }

    static func current(from userDefaults: UserDefaults = .standard) -> AppVisibilityPreferences {
        AppVisibilityPreferences(
            showsMenuBarIcon: userDefaults.object(forKey: AppPreferenceKey.showMenuBarIcon) as? Bool ?? true,
            showsDockIcon: userDefaults.object(forKey: AppPreferenceKey.showDockIcon) as? Bool ?? true
        )
        .normalized
    }

    static func normalizeStoredValues(in userDefaults: UserDefaults = .standard) {
        let currentPreferences = AppVisibilityPreferences.current(from: userDefaults)

        userDefaults.set(currentPreferences.showsMenuBarIcon, forKey: AppPreferenceKey.showMenuBarIcon)
        userDefaults.set(currentPreferences.showsDockIcon, forKey: AppPreferenceKey.showDockIcon)
    }
}

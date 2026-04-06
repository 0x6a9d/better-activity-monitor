import AppKit

extension Notification.Name {
    static let openDashboardSettings = Notification.Name("openDashboardSettings")
}

@MainActor
final class AppLifecycleDelegate: NSObject, NSApplicationDelegate {
    private let userDefaults = UserDefaults.standard
    private var dashboardWindowController: DashboardWindowController?
    private var statusItem: NSStatusItem?
    private lazy var statusMenu = makeStatusMenu()
    private var userDefaultsObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        userDefaults.register(defaults: AppVisibilityPreferences.defaultValues)
        AppVisibilityPreferences.normalizeStoredValues(in: userDefaults)

        guard PlatformSupport.isSupportedHardware() else {
            presentUnsupportedPlatformAlert()
            NSApp.terminate(nil)
            return
        }

        applyAppearanceMode()
        refreshAppVisibility()
        showDashboardWindow()

        userDefaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: userDefaults,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleUserDefaultsChange()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let userDefaultsObserver {
            NotificationCenter.default.removeObserver(userDefaultsObserver)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !currentVisibilityPreferences.shouldStayRunningAfterLastWindowCloses
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showDashboardWindow()
        return true
    }

    func showDashboardSettings() {
        showDashboardWindow()

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .openDashboardSettings, object: nil)
        }
    }

    private var currentVisibilityPreferences: AppVisibilityPreferences {
        AppVisibilityPreferences.current(from: userDefaults)
    }

    private func handleUserDefaultsChange() {
        applyAppearanceMode()
        refreshAppVisibility()
    }

    private func applyAppearanceMode() {
        let storedValue = userDefaults.string(forKey: AppPreferenceKey.appearanceMode) ?? AppearanceMode.auto.rawValue
        AppearanceMode.fromStoredValue(storedValue).applyToApplication()
    }

    private func refreshAppVisibility() {
        let preferences = currentVisibilityPreferences

        NSApp.setActivationPolicy(preferences.activationPolicy)
        updateStatusItemVisibility(showsMenuBarIcon: preferences.showsMenuBarIcon)
    }

    private func updateStatusItemVisibility(showsMenuBarIcon: Bool) {
        guard showsMenuBarIcon else {
            if let statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
                self.statusItem = nil
            }
            return
        }

        if statusItem == nil {
            let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            configureStatusItem(statusItem)
            self.statusItem = statusItem
        } else {
            statusItem?.button?.image = makeStatusItemImage()
        }
    }

    private func configureStatusItem(_ statusItem: NSStatusItem) {
        guard let button = statusItem.button else {
            return
        }

        button.image = makeStatusItemImage()
        button.imageScaling = .scaleProportionallyDown
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "Better Activity Monitor"
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(
            title: "Settings",
            action: #selector(openSettingsFromStatusMenu(_:)),
            keyEquivalent: ""
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quitApplication(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    private func showDashboardWindow() {
        activateApplicationForWindowPresentation()
        let controller = dashboardWindowController ?? DashboardWindowController()
        dashboardWindowController = controller
        controller.present()
    }

    private func activateApplicationForWindowPresentation() {
        refreshAppVisibility()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func presentUnsupportedPlatformAlert() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Apple Silicon Required"
        alert.informativeText = "Better Activity Monitor is intended for Apple Silicon Macs only."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func makeStatusItemImage() -> NSImage {
        let candidateURLs = [
            Bundle.main.url(forResource: "bam-logo-mono", withExtension: "png"),
            Bundle.main.resourceURL?.appendingPathComponent("bam-logo-mono.png"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("bam-logo-mono.png"),
        ]

        if let image = candidateURLs
            .compactMap({ $0 })
            .compactMap(NSImage.init(contentsOf:))
            .first
        {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            return image
        }

        let fallbackImage = NSImage(
            systemSymbolName: "waveform.path.ecg.rectangle",
            accessibilityDescription: "Better Activity Monitor"
        ) ?? NSImage()
        fallbackImage.isTemplate = true
        return fallbackImage
    }

    @objc
    private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        if isSecondaryClick(NSApp.currentEvent) {
            statusMenu.popUp(
                positioning: nil,
                at: NSPoint(x: 0, y: sender.bounds.height + 4),
                in: sender
            )
            return
        }

        showDashboardWindow()
    }

    @objc
    private func openSettingsFromStatusMenu(_ sender: Any?) {
        showDashboardSettings()
    }

    @objc
    private func quitApplication(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    private func isSecondaryClick(_ event: NSEvent?) -> Bool {
        guard let event else {
            return false
        }

        return event.type == .rightMouseUp
            || (event.type == .leftMouseUp && event.modifierFlags.contains(.control))
    }
}

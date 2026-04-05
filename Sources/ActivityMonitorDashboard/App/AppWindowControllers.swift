import AppKit
import SwiftUI

private enum AppWindowIdentifier {
    static let dashboard = NSUserInterfaceItemIdentifier("dashboard-window")
    static let iconSettings = NSUserInterfaceItemIdentifier("icon-settings-window")
}

final class DashboardWindowController: NSWindowController {
    init() {
        let hostingController = NSHostingController(rootView: DashboardView())
        let window = NSWindow(contentViewController: hostingController)

        window.identifier = AppWindowIdentifier.dashboard
        window.title = "Better Activity Monitor"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("BetterActivityMonitorDashboardWindow")

        hostingController.view.layoutSubtreeIfNeeded()
        let fittingSize = hostingController.view.fittingSize
        if fittingSize.width > 0, fittingSize.height > 0 {
            window.setContentSize(fittingSize)
        }

        window.center()

        super.init(window: window)
        shouldCascadeWindows = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        showWindow(nil)

        guard let window else {
            return
        }

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        window.makeKeyAndOrderFront(nil)
    }
}

final class IconSettingsWindowController: NSWindowController {
    init() {
        let hostingController = NSHostingController(rootView: IconSettingsView())
        let window = NSWindow(contentViewController: hostingController)

        window.identifier = AppWindowIdentifier.iconSettings
        window.title = "Icon Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("BetterActivityMonitorIconSettingsWindow")
        window.center()
        window.setContentSize(NSSize(width: 300, height: 148))

        super.init(window: window)
        shouldCascadeWindows = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}

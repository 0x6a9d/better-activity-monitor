import AppKit
import SwiftUI

private enum AppWindowIdentifier {
    static let dashboard = NSUserInterfaceItemIdentifier("dashboard-window")
}

final class DashboardWindowController: NSWindowController, NSWindowDelegate {
    private var isTerminatingFromWindowClose = false

    init() {
        let hostingController = NSHostingController(rootView: DashboardView())
        let window = NSWindow(contentViewController: hostingController)

        window.identifier = AppWindowIdentifier.dashboard
        window.title = "Better Activity Monitor"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
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
        window.delegate = self
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

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard !isTerminatingFromWindowClose else {
            return true
        }

        isTerminatingFromWindowClose = true
        NSApp.terminate(nil)
        return false
    }
}

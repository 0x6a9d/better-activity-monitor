import AppKit
import SwiftUI

private enum AppWindowIdentifier {
    static let dashboard = NSUserInterfaceItemIdentifier("dashboard-window")
}

enum DashboardWindowSizing {
    static let minimumContentSize = NSSize(width: 760, height: 420)

    static func initialContentSize(for fittingSize: NSSize, maximumContentHeight: CGFloat) -> NSSize {
        NSSize(
            width: max(fittingSize.width, minimumContentSize.width),
            height: min(max(fittingSize.height, minimumContentSize.height), maximumContentHeight)
        )
    }

    @MainActor
    static func clampedFrameSize(
        for proposedFrameSize: NSSize,
        in window: NSWindow,
        maximumContentHeight: CGFloat
    ) -> NSSize {
        let proposedContentRect = window.contentRect(forFrameRect: NSRect(origin: .zero, size: proposedFrameSize))
        let clampedContentHeight = min(proposedContentRect.height, maximumContentHeight)
        let clampedFrameRect = window.frameRect(
            forContentRect: NSRect(
                origin: .zero,
                size: NSSize(width: proposedContentRect.width, height: clampedContentHeight)
            )
        )

        return NSSize(width: proposedFrameSize.width, height: clampedFrameRect.height)
    }
}

final class DashboardWindowController: NSWindowController, NSWindowDelegate {
    private var isTerminatingFromWindowClose = false
    private let maximumContentHeight = DashboardLayoutMetrics.maximumContentHeight(
        forRowCount: DashboardCustomization().panelRows.count
    )

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
        window.contentMinSize = DashboardWindowSizing.minimumContentSize
        window.contentMaxSize = NSSize(
            width: window.contentMaxSize.width,
            height: self.maximumContentHeight
        )
        window.setContentSize(
            DashboardWindowSizing.initialContentSize(
                for: fittingSize,
                maximumContentHeight: self.maximumContentHeight
            )
        )

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

        applyVerticalContentLimit(to: window)
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

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        DashboardWindowSizing.clampedFrameSize(
            for: frameSize,
            in: sender,
            maximumContentHeight: maximumContentHeight
        )
    }

    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else {
            return
        }

        applyVerticalContentLimit(to: window)
    }

    private func applyVerticalContentLimit(to window: NSWindow) {
        window.contentMaxSize = NSSize(
            width: window.contentMaxSize.width,
            height: maximumContentHeight
        )

        let currentContentRect = window.contentRect(forFrameRect: window.frame)
        guard currentContentRect.height > maximumContentHeight else {
            return
        }

        window.setContentSize(
            NSSize(
                width: currentContentRect.width,
                height: maximumContentHeight
            )
        )
    }
}

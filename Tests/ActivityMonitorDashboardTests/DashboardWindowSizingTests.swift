import AppKit
import Testing
@testable import ActivityMonitorDashboard

@Test
func dashboardWindowSizingUsesMinimumContentSizeWhenLayoutFitsSmaller() {
    let fittingSize = NSSize(width: 640, height: 320)
    let initialSize = DashboardWindowSizing.initialContentSize(for: fittingSize, maximumContentHeight: 976)

    #expect(initialSize == DashboardWindowSizing.minimumContentSize)
}

@Test
func dashboardWindowSizingPreservesLargerLayoutDimensions() {
    let fittingSize = NSSize(width: 960, height: 840)
    let initialSize = DashboardWindowSizing.initialContentSize(for: fittingSize, maximumContentHeight: 976)

    #expect(initialSize.width == fittingSize.width)
    #expect(initialSize.height == fittingSize.height)
}

@Test
func dashboardWindowSizingClampsInitialHeightToMaximum() {
    let fittingSize = NSSize(width: 960, height: 1320)
    let initialSize = DashboardWindowSizing.initialContentSize(for: fittingSize, maximumContentHeight: 976)

    #expect(initialSize.height == 976)
}

@MainActor
@Test
func dashboardWindowSizingClampsFrameHeightToMaximumContentHeight() {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 960, height: 840),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
    )
    let proposedFrameSize = NSSize(width: 960, height: 1400)

    let clampedSize = DashboardWindowSizing.clampedFrameSize(
        for: proposedFrameSize,
        in: window,
        maximumContentHeight: 976
    )
    let clampedContentHeight = window.contentRect(
        forFrameRect: NSRect(origin: .zero, size: clampedSize)
    ).height

    #expect(clampedContentHeight == 976)
}

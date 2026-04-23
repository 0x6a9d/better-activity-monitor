import SwiftUI

enum DashboardLayoutMetrics {
    static let defaultGraphHeight: CGFloat = 108
    static let minimumGraphHeight: CGFloat = 72
    static let graphResizeExponent: CGFloat = 1.2
    static let totalVerticalPadding: CGFloat = 32
    static let controlsHeight: CGFloat = 48
    static let sectionSpacing: CGFloat = 12
    static let rowSpacing: CGFloat = 12
    static let panelChromeHeight: CGFloat = 104
    static let contentHeightSlack: CGFloat = 36

    static func graphHeight(forContentHeight contentHeight: CGFloat, rowCount: Int) -> CGFloat {
        guard contentHeight > 0, rowCount > 0 else {
            return defaultGraphHeight
        }

        let minimumContentHeight = minimumResizableContentHeight(forRowCount: rowCount)
        let maximumContentHeight = maximumContentHeight(forRowCount: rowCount)
        guard maximumContentHeight > minimumContentHeight else {
            return defaultGraphHeight
        }

        let clampedHeight = min(max(contentHeight, minimumContentHeight), maximumContentHeight)
        let progress = (clampedHeight - minimumContentHeight) / (maximumContentHeight - minimumContentHeight)
        let adjustedProgress = pow(progress, graphResizeExponent)

        return minimumGraphHeight
            + ((defaultGraphHeight - minimumGraphHeight) * adjustedProgress)
    }

    static func maximumContentHeight(forRowCount rowCount: Int) -> CGFloat {
        contentHeight(forRowCount: rowCount, graphHeight: defaultGraphHeight)
    }

    static func minimumResizableContentHeight(forRowCount rowCount: Int) -> CGFloat {
        contentHeight(forRowCount: rowCount, graphHeight: minimumGraphHeight)
    }

    private static func contentHeight(forRowCount rowCount: Int, graphHeight: CGFloat) -> CGFloat {
        guard rowCount > 0 else {
            return totalVerticalPadding + controlsHeight
        }

        let totalRowSpacing = rowSpacing * CGFloat(max(rowCount - 1, 0))

        return totalVerticalPadding
            + controlsHeight
            + sectionSpacing
            + contentHeightSlack
            + totalRowSpacing
            + (CGFloat(rowCount) * (panelChromeHeight + graphHeight))
    }
}

private struct DashboardGraphHeightKey: EnvironmentKey {
    static let defaultValue = DashboardLayoutMetrics.defaultGraphHeight
}

extension EnvironmentValues {
    var dashboardGraphHeight: CGFloat {
        get { self[DashboardGraphHeightKey.self] }
        set { self[DashboardGraphHeightKey.self] = newValue }
    }
}

struct DashboardContentHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

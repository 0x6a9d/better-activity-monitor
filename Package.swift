// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ActivityMonitorDashboard",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "ActivityMonitorDashboardCore",
            targets: ["ActivityMonitorDashboardCore"]
        ),
        .executable(
            name: "ActivityMonitorDashboard",
            targets: ["ActivityMonitorDashboard"]
        ),
    ],
    targets: [
        .target(
            name: "ActivityMonitorDashboardCore",
            path: "Sources/ActivityMonitorDashboardCore"
        ),
        .executableTarget(
            name: "ActivityMonitorDashboard",
            dependencies: ["ActivityMonitorDashboardCore"],
            path: "Sources/ActivityMonitorDashboard"
        ),
        .testTarget(
            name: "ActivityMonitorDashboardCoreTests",
            dependencies: ["ActivityMonitorDashboardCore"],
            path: "Tests/ActivityMonitorDashboardCoreTests"
        ),
    ]
)

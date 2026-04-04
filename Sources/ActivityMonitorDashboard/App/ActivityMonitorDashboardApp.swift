import SwiftUI

@main
struct ActivityMonitorDashboardApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycleDelegate.self) private var appDelegate
    @AppStorage("appearanceMode") private var appearanceModeRawValue = AppearanceMode.auto.rawValue

    var body: some Scene {
        WindowGroup("Better Activity Monitor") {
            DashboardView()
                .onAppear {
                    applyAppearanceMode()
                }
                .onChange(of: appearanceModeRawValue) { _, _ in
                    applyAppearanceMode()
                }
        }
        .windowResizability(.contentSize)
    }

    private var appearanceMode: AppearanceMode {
        AppearanceMode.fromStoredValue(appearanceModeRawValue)
    }

    private func applyAppearanceMode() {
        appearanceMode.applyToApplication()
    }
}

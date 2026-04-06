import SwiftUI

@main
struct ActivityMonitorDashboardApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycleDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    appDelegate.showDashboardSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

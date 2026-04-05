import SwiftUI

struct IconSettingsView: View {
    @AppStorage(AppPreferenceKey.showMenuBarIcon) private var showMenuBarIcon = true
    @AppStorage(AppPreferenceKey.showDockIcon) private var showDockIcon = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Remove icon from menu bar", isOn: hideMenuBarIconBinding)
                .disabled(showMenuBarIcon && !showDockIcon)

            Toggle("Remove icon from Dock", isOn: hideDockIconBinding)
                .disabled(showDockIcon && !showMenuBarIcon)

            Text("At least one app icon stays visible so you can reopen the app.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 300, alignment: .leading)
    }

    private var hideMenuBarIconBinding: Binding<Bool> {
        Binding(
            get: { !showMenuBarIcon },
            set: { showMenuBarIcon = !$0 }
        )
    }

    private var hideDockIconBinding: Binding<Bool> {
        Binding(
            get: { !showDockIcon },
            set: { showDockIcon = !$0 }
        )
    }
}

import SwiftUI

@main
struct DesktopVoiceInputApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appModel = VoiceInputAppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(appModel: appModel)
                .preferredColorScheme(appModel.settings.appearancePreference.colorScheme)
                .id(appModel.appearanceRevision)
        } label: {
            Label("Desktop Voice Input", systemImage: appModel.previewState.menuBarSymbolName)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(appModel: appModel)
                .frame(minWidth: 560, minHeight: 560)
                .preferredColorScheme(appModel.settings.appearancePreference.colorScheme)
        }
    }
}

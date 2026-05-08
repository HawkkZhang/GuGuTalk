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
            ZStack {
                Image("MenuBarIcon")
                    .renderingMode(.template)
                SettingsOpenBridge(appModel: appModel)
                    .frame(width: 0, height: 0)
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(appModel: appModel)
                .frame(minWidth: 560, minHeight: 560)
                .preferredColorScheme(appModel.settings.appearancePreference.colorScheme)
        }
    }
}

private struct SettingsOpenBridge: View {
    @ObservedObject var appModel: VoiceInputAppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: appModel.settingsOpenRequest) { request in
                guard request != nil else { return }
                openSettings()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    appModel.bringSettingsWindowForward()
                }
            }
    }
}

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
                .onAppear {
                    // 将 appModel 传递给 AppDelegate，以便管理设置窗口
                    if let delegate = NSApp.delegate as? AppDelegate {
                        delegate.setupSettingsWindow(appModel: appModel)
                    }
                }
        } label: {
            Image("MenuBarIcon")
                .renderingMode(.template)
        }
        .menuBarExtraStyle(.window)
    }
}

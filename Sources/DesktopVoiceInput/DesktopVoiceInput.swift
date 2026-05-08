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
                    // 在 MenuBarExtra 出现时立即设置窗口
                    if let delegate = NSApp.delegate as? AppDelegate {
                        delegate.setupSettingsWindowIfNeeded(appModel: appModel)
                    }
                }
        } label: {
            Image("MenuBarIcon")
                .renderingMode(.template)
        }
        .menuBarExtraStyle(.window)
    }
}

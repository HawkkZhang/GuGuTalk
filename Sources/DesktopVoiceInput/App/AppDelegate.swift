import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settingsWindow: NSWindow?
    private var settingsHostingController: NSHostingController<SettingsView>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NotificationCenter.default.post(name: .voiceInputAppReopenRequested, object: nil)
        return true
    }

    func setupSettingsWindowIfNeeded(appModel: VoiceInputAppModel) {
        if settingsWindow == nil {
            // 创建原生窗口
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 560),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )

            window.title = "GuGuTalk 设置"
            window.center()
            window.setFrameAutosaveName("GuGuTalkSettingsWindow")
            window.minSize = NSSize(width: 560, height: 560)
            window.isReleasedWhenClosed = false

            // 创建 SwiftUI 视图并嵌入窗口
            let settingsView = SettingsView(appModel: appModel)
            let hostingController = NSHostingController(rootView: settingsView)

            window.contentViewController = hostingController
            window.appearance = appModel.settings.appearancePreference.nsAppearance

            self.settingsWindow = window
            self.settingsHostingController = hostingController

            // 监听设置窗口打开请求
            NotificationCenter.default.addObserver(
                forName: .settingsWindowOpenRequested,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self = self, let window = self.settingsWindow else { return }

                // 如果有指定 tab，更新 appModel
                if let tab = notification.userInfo?["tab"] as? SettingsTab {
                    appModel.prepareSettingsWindow(tab: tab)
                }

                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)

                // 确保窗口在最前面
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    window.orderFrontRegardless()
                }
            }

            // 监听外观变化
            NotificationCenter.default.addObserver(
                forName: .appearanceDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self = self, let window = self.settingsWindow else { return }
                window.appearance = appModel.settings.appearancePreference.nsAppearance
                window.contentView?.needsDisplay = true
            }

            // 窗口设置完成后，检查是否需要打开设置窗口
            if appModel.shouldOpenSettingsOnLaunch {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let tab: SettingsTab = appModel.hasMissingPermissions ? .permissions : .general
                    appModel.showSettingsWindow(tab: tab)
                }
            }
        }
    }
}

extension Notification.Name {
    static let voiceInputAppReopenRequested = Notification.Name("voiceInputAppReopenRequested")
    static let settingsWindowOpenRequested = Notification.Name("settingsWindowOpenRequested")
    static let appearanceDidChange = Notification.Name("AppearanceDidChange")
}

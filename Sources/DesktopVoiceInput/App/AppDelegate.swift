import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate?

    private var settingsWindow: NSWindow?
    private var settingsHostingController: NSHostingController<SettingsView>?
    private weak var appModel: VoiceInputAppModel?
    private var pendingOpenRequest: SettingsTab??  // 双层 Optional 用于区分"无请求"和"无指定 tab"

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NotificationCenter.default.post(name: .voiceInputAppReopenRequested, object: nil)
        return true
    }

    /// 注册 appModel 并立即创建设置窗口
    func registerAppModel(_ appModel: VoiceInputAppModel) {
        guard self.appModel == nil else { return }
        self.appModel = appModel
        setupSettingsWindow(appModel: appModel)

        // 处理待处理的打开请求
        if let pendingTab = pendingOpenRequest {
            pendingOpenRequest = nil
            openSettingsWindow(tab: pendingTab)
        }
    }

    /// 直接打开设置窗口（不通过通知）
    func openSettingsWindow(tab: SettingsTab? = nil) {
        guard let appModel = appModel else {
            // appModel 还没注册，缓存请求
            pendingOpenRequest = tab
            return
        }

        // 确保窗口已创建
        if settingsWindow == nil {
            setupSettingsWindow(appModel: appModel)
        }

        guard let window = settingsWindow else { return }

        if let tab = tab {
            appModel.prepareSettingsWindow(tab: tab)
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.settingsWindow?.orderFrontRegardless()
        }
    }

    private func setupSettingsWindow(appModel: VoiceInputAppModel) {
        guard settingsWindow == nil else { return }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "GuGuTalk 设置"
        window.center()
        window.setFrameAutosaveName("GuGuTalkSettingsWindow")
        window.minSize = NSSize(width: 720, height: 600)
        window.isReleasedWhenClosed = false

        let settingsView = SettingsView(appModel: appModel)
        let hostingController = NSHostingController(rootView: settingsView)

        window.contentViewController = hostingController
        window.appearance = appModel.settings.appearancePreference.nsAppearance

        self.settingsWindow = window
        self.settingsHostingController = hostingController
    }
}

extension Notification.Name {
    static let voiceInputAppReopenRequested = Notification.Name("voiceInputAppReopenRequested")
}

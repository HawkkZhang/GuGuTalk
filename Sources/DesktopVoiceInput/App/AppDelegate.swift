import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NotificationCenter.default.post(name: .voiceInputAppReopenRequested, object: nil)
        return true
    }
}

extension Notification.Name {
    static let voiceInputAppReopenRequested = Notification.Name("voiceInputAppReopenRequested")
}

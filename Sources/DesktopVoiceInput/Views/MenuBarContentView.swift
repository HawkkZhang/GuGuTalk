import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var appModel: VoiceInputAppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Desktop Voice Input")
                    .font(.system(size: 15, weight: .semibold))
                Text("按住 \(appModel.settings.holdToTalkHotkey.displayName) 说话")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("按 \(appModel.settings.toggleToTalkHotkey.displayName) 开始，再按一次结束")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Divider()

            if appModel.hasMissingPermissions {
                PermissionGuideView(appModel: appModel, compact: true)
            }

            if let lastErrorMessage = appModel.lastErrorMessage {
                VStack(alignment: .leading, spacing: 4) {
                    Text("最近错误")
                        .font(.system(size: 12, weight: .medium))
                    Text(lastErrorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()
            }

            statusBlock

            if let lastInsertionResult = appModel.lastInsertionResult {
                VStack(alignment: .leading, spacing: 4) {
                    Text("最近一次插入")
                        .font(.system(size: 12, weight: .medium))
                    Text(lastInsertionResult.succeeded ? "成功，方式：\(lastInsertionResult.method.rawValue)" : (lastInsertionResult.failureReason ?? "失败"))
                        .font(.system(size: 12))
                        .foregroundStyle(lastInsertionResult.succeeded ? Color.secondary : Color.red)
                }
            }

            Divider()

            Button(appModel.hasMissingPermissions ? "请求缺失权限" : "刷新权限状态") {
                if appModel.hasMissingPermissions {
                    appModel.requestPermissions()
                } else {
                    Task {
                        await appModel.permissionCoordinator.refreshAll(promptForSystemDialogs: false)
                    }
                }
            }

            Button("打开权限引导") {
                openSettings()
            }

            Button("打开系统隐私设置") {
                appModel.openSystemSettings()
            }

            Button("打开设置") {
                openSettings()
            }

            Divider()

            Button("退出") {
                appModel.quit()
            }
        }
        .padding(16)
        .frame(width: 340)
    }

    private var statusBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            statusRow(title: "识别模式", value: appModel.settings.preferredMode.title)
            statusRow(title: "麦克风", value: appModel.permissionCoordinator.microphone.title)
            statusRow(title: "语音识别", value: appModel.permissionCoordinator.speechRecognition.title)
            statusRow(title: "辅助功能", value: appModel.permissionCoordinator.accessibility.title)
            statusRow(title: "输入监控", value: appModel.permissionCoordinator.inputMonitoring.title)
        }
    }

    private func statusRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .medium))
            Spacer()
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }
}

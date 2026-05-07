import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var appModel: VoiceInputAppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 状态 + 快捷键
            HStack(alignment: .center, spacing: 8) {
                Circle()
                    .fill(statusTint)
                    .frame(width: 8, height: 8)

                Text(appModel.settings.preferredMode.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DVITheme.ink)

                Text("·")
                    .foregroundStyle(DVITheme.secondaryInk)

                Text(hotkeyDescription)
                    .font(.system(size: 12))
                    .foregroundStyle(DVITheme.secondaryInk)

                Spacer()

                if appModel.previewState.isRecording {
                    Text("录音中")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DVITheme.ready)
                }
            }

            // 模式切换
            Picker("识别模式", selection: $appModel.settings.preferredMode) {
                ForEach(RecognitionMode.userSelectableModes) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .controlSize(.small)

            // 权限提示（仅在缺失时显示）
            if appModel.hasMissingPermissions {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(DVITheme.caution)
                    Text("缺少 \(appModel.missingPermissions.count) 项权限")
                        .font(.system(size: 11))
                        .foregroundStyle(DVITheme.caution)
                    Spacer()
                    Button("处理") { openSettingsWindow(to: .permissions) }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                }
            }

            // 操作
            HStack(spacing: 8) {
                Button("设置") { openSettingsWindow(to: .general) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                Spacer()

                Button("退出") { appModel.quit() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(12)
        .frame(width: 260)
        .background(.regularMaterial)
    }

    private var statusTint: Color {
        if appModel.previewState.isRecording {
            return DVITheme.ready
        }
        if appModel.hasMissingPermissions {
            return DVITheme.caution
        }
        return DVITheme.ready
    }

    private var hotkeyDescription: String {
        if appModel.settings.holdToTalkEnabled {
            return appModel.settings.holdToTalkHotkey.displayName + " 按住说话"
        }
        if appModel.settings.toggleToTalkEnabled {
            return appModel.settings.toggleToTalkHotkey.displayName + " 切换"
        }
        return "未设置快捷键"
    }

    private func openSettingsWindow(to tab: SettingsTab) {
        appModel.prepareSettingsWindow(tab: tab)
        openSettings()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows where !(window is NSPanel) {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        }
    }
}

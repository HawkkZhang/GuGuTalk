import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var appModel: VoiceInputAppModel
    @Environment(\.openSettings) private var openSettings

    private let ink = DVITheme.ink
    private let mutedInk = DVITheme.secondaryInk
    private let brass = DVITheme.caution
    private let moss = DVITheme.ready
    private let crimson = DVITheme.danger

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            statusHeader
            modeSelector

            if appModel.hasMissingPermissions {
                permissionNotice
            }

            if let lastErrorMessage = appModel.lastErrorMessage {
                errorNotice(lastErrorMessage)
            }

            actionsRow
        }
        .padding(10)
        .frame(width: 276)
        .background(.regularMaterial)
    }

    private var statusHeader: some View {
        HStack(alignment: .center, spacing: 9) {
            Circle()
                .fill(statusTint)
                .frame(width: 8, height: 8)
                .shadow(color: statusTint.opacity(appModel.previewState.isRecording ? 0.42 : 0), radius: 5)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(ink)

            Text("\(appModel.settings.preferredMode.title) · \(statusDetail)")
                    .font(.system(size: 11.5))
                    .foregroundStyle(mutedInk)
            }

            Spacer(minLength: 8)

            if appModel.previewState.isRecording {
                Text("录音中")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(moss)
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
    }

    private var modeSelector: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("识别模式")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(mutedInk)

            Picker("识别模式", selection: $appModel.settings.preferredMode) {
                ForEach(RecognitionMode.userSelectableModes) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(DVITheme.panel.opacity(0.76), in: DVITheme.panelShape())
        .overlay(
            DVITheme.panelShape()
                .stroke(DVITheme.separator.opacity(0.24), lineWidth: 1)
        )
    }

    private var permissionNotice: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(brass)
                .frame(width: 18)

            Text("缺少 \(appModel.missingPermissions.count) 项权限")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ink)

            Spacer()

            Button("处理") {
                appModel.requestPermissions()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(DVITheme.panel.opacity(0.78), in: DVITheme.panelShape())
        .overlay(
            DVITheme.panelShape()
                .stroke(DVITheme.stateStroke(brass), lineWidth: 1)
        )
    }

    private func errorNotice(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(crimson)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text("上次失败")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(crimson)
                Text(message)
                    .font(.system(size: 11.5))
                    .foregroundStyle(crimson)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(DVITheme.panel.opacity(0.78), in: DVITheme.panelShape())
        .overlay(
            DVITheme.panelShape()
                .stroke(DVITheme.stateStroke(crimson), lineWidth: 1)
        )
    }

    private var statusTitle: String {
        if appModel.previewState.isRecording {
            return "正在听写"
        }

        if appModel.hasMissingPermissions {
            return "需要处理权限"
        }

        return "可以输入"
    }

    private var statusDetail: String {
        if appModel.hasMissingPermissions {
            return "先补齐权限"
        }

        if !appModel.settings.holdToTalkEnabled, !appModel.settings.toggleToTalkEnabled {
            return "未启用快捷键"
        }

        return "可通过快捷键唤起"
    }

    private var statusTint: Color {
        if appModel.previewState.isRecording {
            return moss
        }

        if appModel.hasMissingPermissions {
            return brass
        }

        if !appModel.settings.holdToTalkEnabled, !appModel.settings.toggleToTalkEnabled {
            return brass
        }

        return moss
    }

    private var actionsRow: some View {
        HStack(spacing: 8) {
            if appModel.hasMissingPermissions {
                Button("权限") {
                    appModel.requestPermissions()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                Button("刷新") {
                    Task {
                        await appModel.permissionCoordinator.refreshAll(promptForSystemDialogs: false)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Button("设置") {
                openSettingsWindow()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()

            Button("退出") {
                appModel.quit()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func openSettingsWindow() {
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

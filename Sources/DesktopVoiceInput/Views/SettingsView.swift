import SwiftUI

struct SettingsView: View {
    @ObservedObject var appModel: VoiceInputAppModel
    @State private var holdHotkeyFeedback: HotkeyValidationIssue?
    @State private var toggleHotkeyFeedback: HotkeyValidationIssue?

    private let primaryText = Color(red: 0.10, green: 0.14, blue: 0.20)
    private let secondaryText = Color(red: 0.36, green: 0.41, blue: 0.49)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                PermissionGuideView(appModel: appModel, compact: false)
                generalSection
                permissionsSection
                doubaoSection
                qwenSection
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.98, green: 0.99, blue: 1.0), Color(red: 0.94, green: 0.96, blue: 0.99)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .foregroundStyle(primaryText)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("桌面语音输入")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(primaryText)
            Text("菜单栏常驻，支持“按住说话”和“按一下开始、再按一下结束”两种触发方式。")
                .font(.system(size: 14))
                .foregroundStyle(secondaryText)
        }
    }

    private var generalSection: some View {
        SettingsCard(title: "通用设置", subtitle: "优先保证低延迟与可日用的中文语音输入体验。") {
            Picker("识别模式", selection: $appModel.settings.preferredMode) {
                ForEach(RecognitionMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            hotkeyRecorderSection(
                slot: .holdToTalk,
                hotkey: $appModel.settings.holdToTalkHotkey,
                feedback: $holdHotkeyFeedback
            )

            hotkeyRecorderSection(
                slot: .toggleToTalk,
                hotkey: $appModel.settings.toggleToTalkHotkey,
                feedback: $toggleHotkeyFeedback
            )

            HStack {
                Text("后处理")
                    .foregroundStyle(primaryText)
                Spacer()
                Text("自动标点 + 中文断句")
                    .foregroundStyle(secondaryText)
            }

            HStack {
                Text("流式插入")
                    .foregroundStyle(primaryText)
                Spacer()
                Text("先预览，结束后一次性插入")
                    .foregroundStyle(secondaryText)
            }
        }
    }

    private func hotkeyRecorderSection(
        slot: HotkeySlot,
        hotkey: Binding<HotkeyConfiguration>,
        feedback: Binding<HotkeyValidationIssue?>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(slot.title)
                .foregroundStyle(primaryText)

            Text(slot.subtitle)
                .font(.system(size: 12))
                .foregroundStyle(secondaryText)

            HotkeyRecorderButton(
                appModel: appModel,
                hotkey: hotkey,
                feedback: feedback,
                validation: { candidate in
                    appModel.settings.validationIssue(for: slot, candidate: candidate)
                }
            )

            let issue = feedback.wrappedValue ?? appModel.settings.validationIssue(for: slot, candidate: hotkey.wrappedValue)
            if let issue {
                Text(issue.message)
                    .font(.system(size: 12))
                    .foregroundStyle(issue.severity == .error ? Color.red : Color.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("冲突处理：大多数应用级快捷键我们会优先截住；系统保留组合和更高优先级的系统行为仍然不能强抢。")
                    .font(.system(size: 12))
                    .foregroundStyle(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var permissionsSection: some View {
        SettingsCard(title: "权限状态", subtitle: "缺哪项就处理哪项。应用回到前台时也会自动刷新当前权限状态。") {
            permissionRow(permission: .microphone, state: appModel.permissionCoordinator.microphone)
            permissionRow(permission: .speechRecognition, state: appModel.permissionCoordinator.speechRecognition)
            permissionRow(permission: .accessibility, state: appModel.permissionCoordinator.accessibility)
            permissionRow(permission: .inputMonitoring, state: appModel.permissionCoordinator.inputMonitoring)

            HStack(spacing: 12) {
                Button("请求缺失权限") {
                    appModel.requestPermissions()
                }

                Button("打开系统设置") {
                    appModel.openSystemSettings()
                }
            }
        }
    }

    private var doubaoSection: some View {
        SettingsCard(title: "豆包语音识别", subtitle: "按官方更推荐的“双向流式优化版”接入，接口地址应为 `wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_async`。") {
            TextField("App ID", text: $appModel.settings.doubaoAppID)
                .textFieldStyle(.roundedBorder)
            SecureField("Access Token", text: $appModel.settings.doubaoAccessKey)
                .textFieldStyle(.roundedBorder)
            TextField("Resource ID", text: $appModel.settings.doubaoResourceID)
                .textFieldStyle(.roundedBorder)
            TextField("Endpoint", text: $appModel.settings.doubaoEndpoint)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var qwenSection: some View {
        SettingsCard(title: "千问语音识别", subtitle: "按 DashScope Realtime 事件流接入，统一走 session.update / append / finish。") {
            SecureField("API Key", text: $appModel.settings.qwenAPIKey)
                .textFieldStyle(.roundedBorder)
            TextField("Model", text: $appModel.settings.qwenModel)
                .textFieldStyle(.roundedBorder)
            TextField("Endpoint", text: $appModel.settings.qwenEndpoint)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func permissionRow(permission: AppPermissionKind, state: PermissionState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(permission.title)
                    .foregroundStyle(primaryText)
                Spacer()
                Text(state.title)
                    .foregroundStyle(state.isUsable ? .green : .orange)
            }

            Text(permission.guidance)
                .font(.system(size: 12))
                .foregroundStyle(secondaryText)

            if !state.isUsable {
                HStack {
                    Button(appModel.actionLabel(for: permission)) {
                        appModel.handlePermissionAction(permission)
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct HotkeyRecorderButton: View {
    let appModel: VoiceInputAppModel
    @Binding var hotkey: HotkeyConfiguration
    @Binding var feedback: HotkeyValidationIssue?
    let validation: (HotkeyConfiguration) -> HotkeyValidationIssue?

    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var livePreview = "等待按键"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button(isRecording ? "停止录制" : "录制快捷键") {
                    isRecording ? stopRecording() : startRecording()
                }
                .buttonStyle(.borderedProminent)

                Text("当前：\(hotkey.displayName)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Text(isRecording ? "录制中：\(livePreview)" : "支持单键或组合键，按 Esc 取消。")
                .font(.system(size: 12))
                .foregroundStyle(isRecording ? Color.accentColor : .secondary)
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        feedback = nil
        livePreview = "等待按键"
        isRecording = true
        appModel.suspendHotkeys()
        NSApp.activate(ignoringOtherApps: true)

        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .keyDown, event.keyCode == 53 {
                stopRecording()
                return nil
            }

            guard let captured = HotkeyConfiguration.capture(from: event) else {
                return nil
            }

            livePreview = captured.displayName

            if let issue = validation(captured), issue.severity == .error {
                feedback = issue
                NSSound.beep()
                stopRecording()
                return nil
            }

            hotkey = captured
            feedback = validation(captured)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        appModel.resumeHotkeys()

        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color(red: 0.10, green: 0.14, blue: 0.20))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red: 0.36, green: 0.41, blue: 0.49))
            }

            content
                .foregroundStyle(Color(red: 0.10, green: 0.14, blue: 0.20))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.7), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 8)
    }
}

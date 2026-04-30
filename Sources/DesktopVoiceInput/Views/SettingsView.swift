import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var appModel: VoiceInputAppModel
    @State private var selectedTab: SettingsTab = .general
    @State private var selectedCloudService: CloudServiceTab = .doubao
    @State private var holdHotkeyFeedback: HotkeyValidationIssue?
    @State private var toggleHotkeyFeedback: HotkeyValidationIssue?

    private let ready = DVITheme.ready
    private let caution = DVITheme.caution

    var body: some View {
        VStack(spacing: 0) {
            header

            TabView(selection: $selectedTab) {
                generalPage
                    .tabItem { Label("常用", systemImage: "slider.horizontal.3") }
                    .tag(SettingsTab.general)

                servicesPage
                    .tabItem { Label("服务", systemImage: "cloud") }
                    .tag(SettingsTab.services)

                permissionsPage
                    .tabItem { Label("权限", systemImage: "lock.shield") }
                    .tag(SettingsTab.permissions)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(DVITheme.window.ignoresSafeArea())
        .foregroundStyle(DVITheme.ink)
        .tint(DVITheme.accent)
        .environment(\.controlActiveState, .active)
        .onAppear {
            bringSettingsWindowForward()
        }
        .onChange(of: appModel.settings.preferredMode) { _, mode in
            if let service = CloudServiceTab(mode: mode) {
                selectedCloudService = service
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("设置")
                .font(.system(size: 22, weight: .semibold))

            Spacer()

            Text(appModel.hasMissingPermissions ? "需要权限" : appModel.settings.preferredMode.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(appModel.hasMissingPermissions ? caution : ready)
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 12)
    }

    private var generalPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsGroup(title: "语音输入") {
                    settingsRow(label: "识别模式") {
                        Picker("识别模式", selection: $appModel.settings.preferredMode) {
                            ForEach(RecognitionMode.userSelectableModes) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .tint(DVITheme.accent)
                        .frame(width: 220)
                    }

                    if appModel.settings.preferredMode != .local {
                        Divider()
                        providerStatus(mode: appModel.settings.preferredMode, isConfigured: isCurrentProviderConfigured)
                    }
                }

                SettingsGroup(title: "快捷键") {
                    hotkeyRecorderSection(
                        slot: .holdToTalk,
                        hotkey: $appModel.settings.holdToTalkHotkey,
                        isEnabled: $appModel.settings.holdToTalkEnabled,
                        feedback: $holdHotkeyFeedback,
                        accent: DVITheme.accent
                    )

                    Divider()

                    hotkeyRecorderSection(
                        slot: .toggleToTalk,
                        hotkey: $appModel.settings.toggleToTalkHotkey,
                        isEnabled: $appModel.settings.toggleToTalkEnabled,
                        feedback: $toggleHotkeyFeedback,
                        accent: DVITheme.accent
                    )
                }

                SettingsGroup(title: "外观") {
                    settingsRow(label: "显示方式") {
                        Picker("外观", selection: $appModel.settings.appearancePreference) {
                            ForEach(AppearancePreference.allCases) { appearance in
                                Text(appearance.title).tag(appearance)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .tint(DVITheme.accent)
                        .frame(width: 220)
                    }
                }
            }
            .padding(.vertical, 12)
        }
    }

    private var servicesPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsGroup(title: "云端参数") {
                    settingsRow(label: "服务") {
                        Picker("云端服务", selection: $selectedCloudService) {
                            ForEach(CloudServiceTab.allCases) { service in
                                Text(service.title).tag(service)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .tint(DVITheme.accent)
                        .frame(width: 180)
                    }

                    Divider()

                    switch selectedCloudService {
                    case .doubao:
                        providerStatus(mode: .doubao, isConfigured: appModel.settings.recognitionConfig.doubaoCredentials.isConfigured)
                        providerField(label: "App ID", text: $appModel.settings.doubaoAppID, secure: false)
                        providerField(label: "Access Token", text: $appModel.settings.doubaoAccessKey, secure: true)
                        providerField(label: "Resource ID", text: $appModel.settings.doubaoResourceID, secure: false)
                        providerField(label: "Endpoint", text: $appModel.settings.doubaoEndpoint, secure: false)
                    case .qwen:
                        providerStatus(mode: .qwen, isConfigured: appModel.settings.recognitionConfig.qwenCredentials.isConfigured)
                        providerField(label: "API Key", text: $appModel.settings.qwenAPIKey, secure: true)
                        providerField(label: "Model", text: $appModel.settings.qwenModel, secure: false)
                        providerField(label: "Endpoint", text: $appModel.settings.qwenEndpoint, secure: false)
                    }
                }
            }
            .padding(.vertical, 12)
        }
    }

    private var permissionsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if appModel.hasMissingPermissions {
                    PermissionGuideView(appModel: appModel, compact: false)
                }

                SettingsGroup(title: "权限状态") {
                    permissionRow(permission: .microphone, state: appModel.permissionCoordinator.microphone)
                    permissionRow(permission: .speechRecognition, state: appModel.permissionCoordinator.speechRecognition)
                    permissionRow(permission: .accessibility, state: appModel.permissionCoordinator.accessibility)
                    permissionRow(permission: .inputMonitoring, state: appModel.permissionCoordinator.inputMonitoring)

                    HStack(spacing: 10) {
                        if appModel.hasMissingPermissions {
                            Button("请求缺失权限") {
                                appModel.requestPermissions()
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button("刷新状态") {
                                Task {
                                    await appModel.permissionCoordinator.refreshAll(promptForSystemDialogs: false)
                                }
                            }
                            .buttonStyle(.bordered)
                        }

                        Button("打开系统设置") {
                            appModel.openSystemSettings()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.vertical, 12)
        }
    }

    private func hotkeyRecorderSection(
        slot: HotkeySlot,
        hotkey: Binding<HotkeyConfiguration>,
        isEnabled: Binding<Bool>,
        feedback: Binding<HotkeyValidationIssue?>,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(slot.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isEnabled.wrappedValue ? DVITheme.ink : DVITheme.secondaryInk)
                }

                Spacer()

                Toggle("", isOn: isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(accent)

                HotkeyRecorderButton(
                    appModel: appModel,
                    hotkey: hotkey,
                    feedback: feedback,
                    validation: { candidate in
                        appModel.settings.validationIssue(for: slot, candidate: candidate)
                    },
                    accent: accent
                )
                .disabled(!isEnabled.wrappedValue)
                .opacity(isEnabled.wrappedValue ? 1 : 0.48)
            }
        }
        .padding(.vertical, 2)
    }

    private func providerField(label: String, text: Binding<String>, secure: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DVITheme.secondaryInk)

            Group {
                if secure {
                    SecureField(label, text: text)
                } else {
                    TextField(label, text: text)
                }
            }
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 13, weight: .regular, design: .monospaced))
        }
    }

    private func settingsRow<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DVITheme.ink)

            Spacer()

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func providerStatus(mode: RecognitionMode, isConfigured: Bool) -> some View {
        HStack(spacing: 8) {
            let isActive = appModel.settings.preferredMode == mode
            Image(systemName: isConfigured ? "checkmark" : "exclamationmark.triangle.fill")
                .foregroundStyle(isConfigured ? ready : caution)
            Text(isActive ? "当前使用" : (isConfigured ? "已配置" : "未配置"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isActive ? DVITheme.accent : DVITheme.secondaryInk)
        }
        .padding(.bottom, 2)
    }

    private var isCurrentProviderConfigured: Bool {
        switch appModel.settings.preferredMode {
        case .doubao:
            appModel.settings.recognitionConfig.doubaoCredentials.isConfigured
        case .qwen:
            appModel.settings.recognitionConfig.qwenCredentials.isConfigured
        case .auto, .local:
            true
        }
    }

    private func permissionRow(permission: AppPermissionKind, state: PermissionState) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: state.isUsable ? "checkmark" : "exclamationmark.triangle.fill")
                .foregroundStyle(state.isUsable ? ready : caution)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(permission.title)
                    .font(.system(size: 13, weight: .medium))
                if !state.isUsable {
                    Text(permission.guidance)
                        .font(.system(size: 12))
                        .foregroundStyle(DVITheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            if state.isUsable {
                Text(state.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DVITheme.secondaryInk)
            } else {
                Button(appModel.actionLabel(for: permission)) {
                    appModel.handlePermissionAction(permission)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }

    private func bringSettingsWindowForward() {
        activateSettingsWindow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            activateSettingsWindow()
        }
    }

    private func activateSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)

        for window in NSApp.windows where !(window is NSPanel) {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }
}

private enum SettingsTab {
    case general
    case services
    case permissions
}

private enum CloudServiceTab: CaseIterable, Identifiable {
    case doubao
    case qwen

    init?(mode: RecognitionMode) {
        switch mode {
        case .doubao:
            self = .doubao
        case .qwen:
            self = .qwen
        case .auto, .local:
            return nil
        }
    }

    var id: Self { self }

    var title: String {
        switch self {
        case .doubao:
            "豆包"
        case .qwen:
            "千问"
        }
    }
}

private struct HotkeyRecorderButton: View {
    let appModel: VoiceInputAppModel
    @Binding var hotkey: HotkeyConfiguration
    @Binding var feedback: HotkeyValidationIssue?
    let validation: (HotkeyConfiguration) -> HotkeyValidationIssue?
    let accent: Color

    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var livePreview = "等待按键"

    var body: some View {
        HStack(spacing: 8) {
            Text(isRecording ? livePreview : hotkey.displayName)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(isRecording ? accent : DVITheme.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .frame(minWidth: 88)
                .background(isRecording ? DVITheme.stateFill(accent, emphasized: true) : DVITheme.control, in: DVITheme.controlShape())
                .overlay(
                    DVITheme.controlShape()
                        .stroke(isRecording ? DVITheme.stateStroke(accent, emphasized: true) : DVITheme.separator.opacity(0.42), lineWidth: 1)
                )

            if isRecording {
                Button {
                    stopRecording()
                } label: {
                    Label("停止", systemImage: "stop.fill")
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    startRecording()
                } label: {
                    Label("录制", systemImage: "keyboard")
                }
                .buttonStyle(.bordered)
            }
        }
        .animation(.easeOut(duration: 0.16), value: isRecording)
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        feedback = nil
        livePreview = "按键中"
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

private struct SettingsGroup<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(DVITheme.secondaryInk)
                }
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DVITheme.panel, in: DVITheme.panelShape())
        .overlay(
            DVITheme.panelShape()
                .stroke(DVITheme.separator.opacity(0.42), lineWidth: 1)
        )
    }
}

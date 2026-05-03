import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var appModel: VoiceInputAppModel
    @State private var selectedTab: SettingsTab = .general
    @State private var holdHotkeyFeedback: HotkeyValidationIssue?
    @State private var toggleHotkeyFeedback: HotkeyValidationIssue?
    @State private var replacementFrom: String = ""
    @State private var replacementTo: String = ""
    @Namespace private var sidebarAnimation

    private let ready = DVITheme.ready
    private let caution = DVITheme.caution

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider().ignoresSafeArea()
            contentArea
        }
        .background(DVITheme.window.ignoresSafeArea())
        .foregroundStyle(DVITheme.ink)
        .tint(DVITheme.accent)
        .environment(\.controlActiveState, .active)
        .onAppear { bringSettingsWindowForward() }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("设置")
                .font(.system(size: 18, weight: .semibold))
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

            VStack(spacing: 2) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    sidebarItem(tab)
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            statusBadge
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .frame(width: 150)
        .background(DVITheme.elevatedPanel.opacity(0.5))
    }

    private func sidebarItem(_ tab: SettingsTab) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.system(size: 13))
                    .frame(width: 18)
                Text(tab.title)
                    .font(.system(size: 13, weight: selectedTab == tab ? .medium : .regular))

                Spacer()

                if tab == .permissions, appModel.hasMissingPermissions {
                    Circle()
                        .fill(caution)
                        .frame(width: 6, height: 6)
                }
            }
            .foregroundStyle(selectedTab == tab ? DVITheme.accent : DVITheme.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background {
                if selectedTab == tab {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(DVITheme.stateFill(DVITheme.accent, emphasized: true))
                        .matchedGeometryEffect(id: "sidebar_highlight", in: sidebarAnimation)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(appModel.hasMissingPermissions ? caution : ready)
                .frame(width: 7, height: 7)
            Text(appModel.hasMissingPermissions ? "需要权限" : appModel.settings.preferredMode.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DVITheme.secondaryInk)
        }
    }

    // MARK: - Content Area

    private var contentArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                switch selectedTab {
                case .general: generalContent
                case .postProcessing: postProcessingContent
                case .permissions: permissionsContent
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .id(selectedTab)
        .transition(.opacity.animation(.easeOut(duration: 0.15)))
    }

    // MARK: - General

    private var generalContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            SectionHeader("语音输入")
            SettingsPanel {
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

                if appModel.settings.preferredMode == .doubao {
                    Divider()
                    providerStatus(mode: .doubao, isConfigured: appModel.settings.recognitionConfig.doubaoCredentials.isConfigured)
                    providerField(label: "App ID", text: $appModel.settings.doubaoAppID, secure: false)
                    providerField(label: "Access Token", text: $appModel.settings.doubaoAccessKey, secure: true)
                    providerField(label: "Resource ID", text: $appModel.settings.doubaoResourceID, secure: false)
                    providerField(label: "Endpoint", text: $appModel.settings.doubaoEndpoint, secure: false)
                }

                if appModel.settings.preferredMode == .qwen {
                    Divider()
                    providerStatus(mode: .qwen, isConfigured: appModel.settings.recognitionConfig.qwenCredentials.isConfigured)
                    providerField(label: "API Key", text: $appModel.settings.qwenAPIKey, secure: true)
                    providerField(label: "Model", text: $appModel.settings.qwenModel, secure: false)
                    providerField(label: "Endpoint", text: $appModel.settings.qwenEndpoint, secure: false)
                }
            }
            .animation(.easeOut(duration: 0.2), value: appModel.settings.preferredMode)

            SectionHeader("快捷键")
            SettingsPanel {
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

            SectionHeader("外观")
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

    // MARK: - Post Processing

    private var postProcessingContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            SectionHeader("标点")
            settingsRow(label: "标点处理") {
                Picker("标点", selection: $appModel.settings.punctuationMode) {
                    ForEach(PunctuationMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .tint(DVITheme.accent)
                .frame(width: 280)
            }

            SectionHeader("文本替换")
            SettingsPanel {
                HStack(spacing: 8) {
                    TextField("识别结果", text: $replacementFrom)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11))
                        .foregroundStyle(DVITheme.secondaryInk)
                    TextField("替换为", text: $replacementTo)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                    Button("添加") { addReplacement() }
                        .buttonStyle(.bordered)
                        .disabled(replacementFrom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                 replacementTo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if !appModel.hotwordStore.replacements.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(appModel.hotwordStore.replacements) { r in
                            HStack(spacing: 8) {
                                Text(r.from)
                                    .font(.system(size: 12))
                                    .foregroundStyle(DVITheme.secondaryInk)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10))
                                    .foregroundStyle(DVITheme.tertiaryInk)
                                Text(r.to)
                                    .font(.system(size: 12, weight: .medium))
                                Spacer()
                                Button { appModel.hotwordStore.remove(r.from) } label: {
                                    Image(systemName: "xmark").font(.system(size: 10))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(DVITheme.tertiaryInk)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } else {
                    Text("将识别结果中的特定词替换为正确写法")
                        .font(.system(size: 12))
                        .foregroundStyle(DVITheme.secondaryInk)
                }
            }

            SectionHeader("智能后处理")
            SettingsPanel {
                HStack {
                    Text("启用智能后处理")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Toggle("", isOn: $appModel.settings.postProcessingEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(DVITheme.accent)
                }

                if appModel.settings.postProcessingEnabled {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("处理模式")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DVITheme.secondaryInk)
                        HStack(spacing: 6) {
                            ForEach(PostProcessingPreset.allCases) { preset in
                                presetButton(preset)
                            }
                        }
                    }

                    if let preset = appModel.settings.postProcessingPreset {
                        Divider()
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Prompt")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(DVITheme.secondaryInk)
                                Spacer()
                                if !appModel.settings.customPrompt(for: preset).isEmpty {
                                    Button("恢复默认") {
                                        appModel.settings.setCustomPrompt("", for: preset)
                                    }
                                    .font(.system(size: 11))
                                    .buttonStyle(.plain)
                                    .foregroundStyle(DVITheme.accent)
                                }
                            }
                            TextEditor(text: Binding(
                                get: { appModel.settings.effectivePrompt(for: preset) },
                                set: { appModel.settings.setCustomPrompt($0, for: preset) }
                            ))
                            .font(.system(size: 12))
                            .frame(height: 72)
                            .scrollContentBackground(.hidden)
                            .padding(6)
                            .background(DVITheme.control, in: RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(DVITheme.separator.opacity(0.3), lineWidth: 1))
                        }
                    }
                }
            }
            .animation(.easeOut(duration: 0.2), value: appModel.settings.postProcessingEnabled)
            .animation(.easeOut(duration: 0.2), value: appModel.settings.postProcessingPreset)

            if appModel.settings.postProcessingEnabled {
                SectionHeader("LLM 服务")
                SettingsPanel {
                    llmConfigStatus
                    settingsRow(label: "协议") {
                        Picker("协议", selection: $appModel.settings.llmProtocolType) {
                            ForEach(LLMProtocolType.allCases) { proto in
                                Text(proto.title).tag(proto)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .tint(DVITheme.accent)
                        .frame(width: 200)
                    }
                    providerField(label: "Endpoint", text: $appModel.settings.llmEndpoint, secure: false)
                    providerField(label: "API Key", text: $appModel.settings.llmAPIKey, secure: true)
                    providerField(label: "Model", text: $appModel.settings.llmModel, secure: false)
                    Text(appModel.settings.llmProtocolType.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(DVITheme.tertiaryInk)
                }
            }
        }
    }

    // MARK: - Permissions

    private var permissionsContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            if appModel.hasMissingPermissions {
                PermissionGuideView(appModel: appModel, compact: false)
            }
            SectionHeader("权限状态")
            SettingsPanel {
                VStack(spacing: 2) {
                    permissionRow(permission: .microphone, state: appModel.permissionCoordinator.microphone)
                    permissionRow(permission: .speechRecognition, state: appModel.permissionCoordinator.speechRecognition)
                    permissionRow(permission: .accessibility, state: appModel.permissionCoordinator.accessibility)
                    permissionRow(permission: .inputMonitoring, state: appModel.permissionCoordinator.inputMonitoring)
                }
                HStack(spacing: 10) {
                    if appModel.hasMissingPermissions {
                        Button("请求缺失权限") { appModel.requestPermissions() }.buttonStyle(.borderedProminent)
                    } else {
                        Button("刷新状态") { Task { await appModel.permissionCoordinator.refreshAll(promptForSystemDialogs: false) } }.buttonStyle(.bordered)
                    }
                    Button("打开系统设置") { appModel.openSystemSettings() }.buttonStyle(.bordered)
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Helpers

    private func presetButton(_ preset: PostProcessingPreset) -> some View {
        let sel = appModel.settings.postProcessingPreset == preset
        return Button {
            withAnimation(.easeOut(duration: 0.15)) { appModel.settings.postProcessingPreset = sel ? nil : preset }
        } label: {
            Text(preset.title).font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(sel ? DVITheme.stateFill(DVITheme.accent, emphasized: true) : DVITheme.control, in: DVITheme.controlShape())
                .overlay(DVITheme.controlShape().stroke(sel ? DVITheme.stateStroke(DVITheme.accent, emphasized: true) : DVITheme.separator.opacity(0.3), lineWidth: 1))
                .foregroundStyle(sel ? DVITheme.accent : DVITheme.ink)
                .scaleEffect(sel ? 1.02 : 1.0)
        }
        .buttonStyle(.plain).animation(.easeOut(duration: 0.12), value: sel)
    }

    private func addReplacement() {
        let f = replacementFrom.trimmingCharacters(in: .whitespacesAndNewlines)
        let t = replacementTo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !f.isEmpty, !t.isEmpty else { return }
        appModel.hotwordStore.add(from: f, to: t); replacementFrom = ""; replacementTo = ""
    }

    private var llmConfigStatus: some View {
        let ok = appModel.settings.llmProviderConfig.isConfigured
        return HStack(spacing: 8) {
            Image(systemName: ok ? "checkmark" : "exclamationmark.triangle.fill").foregroundStyle(ok ? ready : caution)
            Text(ok ? "已配置" : "未配置").font(.system(size: 12, weight: .medium)).foregroundStyle(ok ? DVITheme.secondaryInk : caution)
        }.padding(.bottom, 2)
    }

    private func hotkeyRecorderSection(slot: HotkeySlot, hotkey: Binding<HotkeyConfiguration>, isEnabled: Binding<Bool>, feedback: Binding<HotkeyValidationIssue?>, accent: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(slot.title).font(.system(size: 13, weight: .medium)).foregroundStyle(isEnabled.wrappedValue ? DVITheme.ink : DVITheme.secondaryInk)
            Spacer()
            Toggle("", isOn: isEnabled).labelsHidden().toggleStyle(.switch).tint(accent)
            HotkeyRecorderButton(appModel: appModel, hotkey: hotkey, feedback: feedback, validation: { appModel.settings.validationIssue(for: slot, candidate: $0) }, accent: accent)
                .disabled(!isEnabled.wrappedValue).opacity(isEnabled.wrappedValue ? 1 : 0.48)
        }.padding(.vertical, 2)
    }

    private func providerField(label: String, text: Binding<String>, secure: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(DVITheme.secondaryInk)
            Group { if secure { SecureField(label, text: text) } else { TextField(label, text: text) } }
                .textFieldStyle(.roundedBorder).font(.system(size: 13, weight: .regular, design: .monospaced))
        }
    }

    private func settingsRow<C: View>(label: String, @ViewBuilder content: () -> C) -> some View {
        HStack(alignment: .center, spacing: 12) { Text(label).font(.system(size: 13, weight: .medium)); Spacer(); content() }
    }

    private func providerStatus(mode: RecognitionMode, isConfigured: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isConfigured ? "checkmark" : "exclamationmark.triangle.fill").foregroundStyle(isConfigured ? ready : caution)
            Text(isConfigured ? "已配置" : "未配置").font(.system(size: 12, weight: .medium)).foregroundStyle(isConfigured ? DVITheme.secondaryInk : caution)
        }
    }

    private func permissionRow(permission: AppPermissionKind, state: PermissionState) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: state.isUsable ? "checkmark" : "exclamationmark.triangle.fill").foregroundStyle(state.isUsable ? ready : caution).frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(permission.title).font(.system(size: 13, weight: .medium))
                if !state.isUsable { Text(permission.guidance).font(.system(size: 12)).foregroundStyle(DVITheme.secondaryInk).fixedSize(horizontal: false, vertical: true) }
            }
            Spacer()
            if state.isUsable { Text(state.title).font(.system(size: 12, weight: .medium)).foregroundStyle(DVITheme.secondaryInk) }
            else { Button(appModel.actionLabel(for: permission)) { appModel.handlePermissionAction(permission) }.buttonStyle(.bordered) }
        }.padding(.vertical, 4)
    }

    private func bringSettingsWindowForward() {
        activateSettingsWindow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { activateSettingsWindow() }
    }

    private func activateSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where !(window is NSPanel) { window.makeKeyAndOrderFront(nil); window.orderFrontRegardless() }
    }
}

// MARK: - Types

private enum SettingsTab: CaseIterable {
    case general, postProcessing, permissions
    var title: String {
        switch self { case .general: "常用"; case .postProcessing: "后处理"; case .permissions: "权限" }
    }
    var icon: String {
        switch self { case .general: "slider.horizontal.3"; case .postProcessing: "wand.and.stars"; case .permissions: "lock.shield" }
    }
}

// MARK: - Components

private struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View { Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(DVITheme.secondaryInk) }
}

private struct SettingsPanel<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(DVITheme.panel, in: DVITheme.panelShape())
            .overlay(DVITheme.panelShape().stroke(DVITheme.separator.opacity(0.24), lineWidth: 1))
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
                .padding(.horizontal, 10).padding(.vertical, 5).frame(minWidth: 88)
                .background(isRecording ? DVITheme.stateFill(accent, emphasized: true) : DVITheme.control, in: DVITheme.controlShape())
                .overlay(DVITheme.controlShape().stroke(isRecording ? DVITheme.stateStroke(accent, emphasized: true) : DVITheme.separator.opacity(0.42), lineWidth: 1))
            if isRecording {
                Button { stopRecording() } label: { Label("停止", systemImage: "stop.fill") }.buttonStyle(.borderedProminent)
            } else {
                Button { startRecording() } label: { Label("录制", systemImage: "keyboard") }.buttonStyle(.bordered)
            }
        }
        .animation(.easeOut(duration: 0.16), value: isRecording)
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        feedback = nil; livePreview = "按键中"; isRecording = true
        appModel.suspendHotkeys(); NSApp.activate(ignoringOtherApps: true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .keyDown, event.keyCode == 53 { stopRecording(); return nil }
            guard let captured = HotkeyConfiguration.capture(from: event) else { return nil }
            livePreview = captured.displayName
            if let issue = validation(captured), issue.severity == .error { feedback = issue; NSSound.beep(); stopRecording(); return nil }
            hotkey = captured; feedback = validation(captured); stopRecording(); return nil
        }
    }

    private func stopRecording() {
        isRecording = false; appModel.resumeHotkeys()
        if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? .infinity; var x: CGFloat = 0, y: CGFloat = 0, h: CGFloat = 0
        for s in subviews { let sz = s.sizeThatFits(.unspecified); if x + sz.width > w, x > 0 { x = 0; y += h + spacing; h = 0 }; x += sz.width + spacing; h = max(h, sz.height) }
        return CGSize(width: w, height: y + h)
    }
    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = b.minX, y = b.minY, h: CGFloat = 0
        for s in subviews { let sz = s.sizeThatFits(.unspecified); if x + sz.width > b.maxX, x > b.minX { x = b.minX; y += h + spacing; h = 0 }; s.place(at: CGPoint(x: x, y: y), proposal: .unspecified); x += sz.width + spacing; h = max(h, sz.height) }
    }
}

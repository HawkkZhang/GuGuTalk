import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var appModel: VoiceInputAppModel
    @State private var selectedTab: SettingsTab = .general
    @State private var holdHotkeyFeedback: HotkeyValidationIssue?
    @State private var toggleHotkeyFeedback: HotkeyValidationIssue?
    @State private var replacementFrom: String = ""
    @State private var replacementTo: String = ""
    @State private var isDoubaoConfigExpanded = false
    @State private var isQwenConfigExpanded = false
    @State private var isAddingCustomMode = false
    @State private var newModeName: String = ""
    @State private var newModePrompt: String = ""
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
        .onAppear {
            selectedTab = appModel.requestedSettingsTab
            bringSettingsWindowForward()
            // 检测是否已配置，如果未配置则自动展开
            isDoubaoConfigExpanded = appModel.settings.doubaoAppID.isEmpty || appModel.settings.doubaoAccessKey.isEmpty
            isQwenConfigExpanded = appModel.settings.qwenAPIKey.isEmpty
        }
        .onChange(of: appModel.requestedSettingsTab) { tab in
            withAnimation(.easeOut(duration: 0.2)) {
                selectedTab = tab
            }
            bringSettingsWindowForward()
        }
        .onChange(of: appModel.settingsFocusRequest) { _ in
            bringSettingsWindowForward()
        }
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

                    DisclosureGroup(isExpanded: $isDoubaoConfigExpanded) {
                        VStack(spacing: 12) {
                            providerField(label: "App ID", text: $appModel.settings.doubaoAppID, secure: false)
                            providerField(label: "Access Token", text: $appModel.settings.doubaoAccessKey, secure: true)
                            providerField(label: "Resource ID", text: $appModel.settings.doubaoResourceID, secure: false)
                            providerField(label: "Endpoint", text: $appModel.settings.doubaoEndpoint, secure: false)
                        }
                        .padding(.top, 8)
                    } label: {
                        HStack {
                            Image(systemName: "gearshape")
                                .font(.system(size: 12))
                                .foregroundStyle(DVITheme.accent)
                            Text("配置参数")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(DVITheme.ink)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                if appModel.settings.preferredMode == .qwen {
                    Divider()
                    providerStatus(mode: .qwen, isConfigured: appModel.settings.recognitionConfig.qwenCredentials.isConfigured)

                    DisclosureGroup(isExpanded: $isQwenConfigExpanded) {
                        VStack(spacing: 12) {
                            providerField(label: "API Key", text: $appModel.settings.qwenAPIKey, secure: true)
                            providerField(label: "Model", text: $appModel.settings.qwenModel, secure: false)
                            providerField(label: "Endpoint", text: $appModel.settings.qwenEndpoint, secure: false)
                        }
                        .padding(.top, 8)
                    } label: {
                        HStack {
                            Image(systemName: "gearshape")
                                .font(.system(size: 12))
                                .foregroundStyle(DVITheme.accent)
                            Text("配置参数")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(DVITheme.ink)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .animation(.easeOut(duration: 0.2), value: appModel.settings.preferredMode)

            SectionHeader("快捷键")
            HStack(alignment: .top, spacing: 12) {
                hotkeyModeCard(
                    title: "按住说话",
                    description: "按住快捷键说话，松开后插入文本",
                    icon: "hand.tap",
                    hotkey: $appModel.settings.holdToTalkHotkey,
                    isEnabled: $appModel.settings.holdToTalkEnabled,
                    feedback: $holdHotkeyFeedback,
                    slot: .holdToTalk,
                    otherHotkey: appModel.settings.toggleToTalkHotkey
                )
                .frame(maxWidth: .infinity)

                hotkeyModeCard(
                    title: "按一下说话",
                    description: "按一下开始，再按一下结束",
                    icon: "circle.circle",
                    hotkey: $appModel.settings.toggleToTalkHotkey,
                    isEnabled: $appModel.settings.toggleToTalkEnabled,
                    feedback: $toggleHotkeyFeedback,
                    slot: .toggleToTalk,
                    otherHotkey: appModel.settings.holdToTalkHotkey
                )
                .frame(maxWidth: .infinity)
            }
            .fixedSize(horizontal: false, vertical: true)

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
            SectionHeader("标点处理")
            SettingsPanel {
                Picker("标点处理", selection: $appModel.settings.punctuationMode) {
                    ForEach(PunctuationMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .tint(DVITheme.accent)
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
                        Picker("处理模式", selection: Binding(
                            get: { appModel.settings.postProcessingPreset ?? .removeFillers },
                            set: {
                                appModel.settings.postProcessingPreset = $0
                                appModel.settings.selectedCustomModeName = nil
                            }
                        )) {
                            ForEach(PostProcessingPreset.allCases) { preset in
                                Text(preset.title).tag(preset)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .tint(DVITheme.accent)
                    }

                    // 自定义模式列表
                    if !appModel.settings.customModes.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 6) {
                            Text("自定义")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(DVITheme.secondaryInk)

                            ForEach(appModel.settings.customModes) { mode in
                                HStack(spacing: 8) {
                                    Button {
                                        appModel.settings.selectedCustomModeName = mode.name
                                        appModel.settings.postProcessingPreset = nil
                                    } label: {
                                        Text(mode.name)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(appModel.settings.selectedCustomModeName == mode.name ? .white : DVITheme.ink)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(
                                                appModel.settings.selectedCustomModeName == mode.name
                                                    ? DVITheme.accent
                                                    : DVITheme.control,
                                                in: DVITheme.controlShape()
                                            )
                                    }
                                    .buttonStyle(.plain)

                                    Spacer()

                                    Button {
                                        appModel.settings.removeCustomMode(name: mode.name)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 10))
                                            .foregroundStyle(DVITheme.tertiaryInk)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // 选中自定义模式时显示 prompt 编辑
                    if let customName = appModel.settings.selectedCustomModeName,
                       let mode = appModel.settings.customModes.first(where: { $0.name == customName }) {
                        Divider()
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Prompt")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(DVITheme.secondaryInk)
                            TextEditor(text: Binding(
                                get: { mode.prompt },
                                set: { appModel.settings.updateCustomMode(name: customName, prompt: $0) }
                            ))
                            .font(.system(size: 12))
                            .frame(height: 72)
                            .scrollContentBackground(.hidden)
                            .padding(6)
                            .background(DVITheme.control, in: RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(DVITheme.separator.opacity(0.3), lineWidth: 1))
                        }
                    }

                    // 添加自定义模式
                    Divider()
                    if isAddingCustomMode {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("模式名称", text: $newModeName)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))
                            TextEditor(text: $newModePrompt)
                                .font(.system(size: 12))
                                .frame(height: 60)
                                .scrollContentBackground(.hidden)
                                .padding(6)
                                .background(DVITheme.control, in: RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(DVITheme.separator.opacity(0.3), lineWidth: 1))
                            HStack {
                                Button("添加") {
                                    let name = newModeName.trimmingCharacters(in: .whitespacesAndNewlines)
                                    let prompt = newModePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !name.isEmpty, !prompt.isEmpty else { return }
                                    appModel.settings.addCustomMode(name: name, prompt: prompt)
                                    appModel.settings.selectedCustomModeName = name
                                    appModel.settings.postProcessingPreset = nil
                                    newModeName = ""
                                    newModePrompt = ""
                                    isAddingCustomMode = false
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .disabled(newModeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newModePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                                Button("取消") {
                                    newModeName = ""
                                    newModePrompt = ""
                                    isAddingCustomMode = false
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    } else {
                        Button {
                            isAddingCustomMode = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 12))
                                Text("添加自定义模式")
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(DVITheme.accent)
                        }
                        .buttonStyle(.plain)
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
            PermissionGuideView(appModel: appModel, compact: false)
        }
    }

    // MARK: - Helpers

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

    private func hotkeyModeCard(
        title: String,
        description: String,
        icon: String,
        hotkey: Binding<HotkeyConfiguration>,
        isEnabled: Binding<Bool>,
        feedback: Binding<HotkeyValidationIssue?>,
        slot: HotkeySlot,
        otherHotkey: HotkeyConfiguration
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(DVITheme.accent)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DVITheme.ink)
                        .lineLimit(1)

                    Text(description)
                        .font(.system(size: 11))
                        .foregroundStyle(DVITheme.secondaryInk)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Toggle("", isOn: isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(DVITheme.accent)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HotkeyRecorderButton(
                    appModel: appModel,
                    hotkey: hotkey,
                    feedback: feedback,
                    validation: { appModel.settings.validationIssue(for: slot, candidate: $0) },
                    accent: DVITheme.accent
                )
                .disabled(!isEnabled.wrappedValue)
                .opacity(isEnabled.wrappedValue ? 1 : 0.48)

                // 实时显示冲突和警告
                let conflictInfo = hotkey.wrappedValue.conflictInfo(comparing: otherHotkey)
                if conflictInfo.severity != .none {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: conflictInfo.severity == .error ? "exclamationmark.triangle.fill" : "info.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(conflictInfo.severity == .error ? DVITheme.caution : .blue)
                            .padding(.top, 1)

                        VStack(alignment: .leading, spacing: 4) {
                            if let title = conflictInfo.title {
                                Text(title)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(conflictInfo.severity == .error ? DVITheme.caution : .blue)
                            }
                            ForEach(conflictInfo.details, id: \.self) { detail in
                                Text(detail)
                                    .font(.system(size: 10))
                                    .foregroundStyle(DVITheme.secondaryInk)
                            }
                        }
                    }
                    .padding(8)
                    .background(
                        (conflictInfo.severity == .error ? DVITheme.caution : Color.blue).opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                }

                if let issue = feedback.wrappedValue {
                    HStack(spacing: 6) {
                        Image(systemName: issue.severity == .error ? "exclamationmark.triangle.fill" : "info.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(issue.severity == .error ? DVITheme.caution : .orange)
                        Text(issue.message)
                            .font(.system(size: 10))
                            .foregroundStyle(DVITheme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(8)
                    .background(
                        (issue.severity == .error ? DVITheme.caution : Color.orange).opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .background(DVITheme.control, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(DVITheme.separator.opacity(0.5), lineWidth: 1)
        )
    }

    private func hotkeyRecorderSection(slot: HotkeySlot, hotkey: Binding<HotkeyConfiguration>, isEnabled: Binding<Bool>, feedback: Binding<HotkeyValidationIssue?>, accent: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(slot.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isEnabled.wrappedValue ? DVITheme.ink : DVITheme.secondaryInk)

            Spacer()

            Toggle("", isOn: isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(accent)

            HotkeyRecorderButton(
                appModel: appModel,
                hotkey: hotkey,
                feedback: feedback,
                validation: { appModel.settings.validationIssue(for: slot, candidate: $0) },
                accent: accent
            )
            .disabled(!isEnabled.wrappedValue)
            .opacity(isEnabled.wrappedValue ? 1 : 0.48)

            HotkeyConflictIndicator(
                hotkey: hotkey.wrappedValue,
                otherHotkey: slot == .holdToTalk ? appModel.settings.toggleToTalkHotkey : appModel.settings.holdToTalkHotkey
            )
        }
        .padding(.vertical, 2)
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

enum SettingsTab: CaseIterable {
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
    @State private var liveModifiers: NSEvent.ModifierFlags = []
    @State private var liveKeyCode: UInt16? = nil
    @State private var shakeOffset: CGFloat = 0
    @State private var isRejected = false
    @State private var capturedHotkey: HotkeyConfiguration?

    var body: some View {
        Button {
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        } label: {
            HStack(spacing: 6) {
                if isRecording {
                    LiveHotkeyDisplay(modifiers: liveModifiers, keyCode: liveKeyCode, accent: accent, isRejected: isRejected)
                } else {
                    HotkeyDisplay(hotkey: hotkey)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(minWidth: 140)
        }
        .buttonStyle(.plain)
        .background(isRecording ? DVITheme.stateFill(accent, emphasized: true) : DVITheme.control, in: DVITheme.controlShape())
        .overlay(DVITheme.controlShape().stroke(isRecording ? DVITheme.stateStroke(accent, emphasized: true) : DVITheme.separator.opacity(0.42), lineWidth: 1))
        .offset(x: shakeOffset)
        .animation(.easeOut(duration: 0.16), value: isRecording)
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        feedback = nil
        isRejected = false
        liveModifiers = []
        liveKeyCode = nil
        capturedHotkey = nil
        isRecording = true
        appModel.suspendHotkeys()
        NSApp.activate(ignoringOtherApps: true)

        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
            if event.type == .keyDown {
                if event.keyCode == 53 {
                    stopRecording()
                    return nil
                }

                liveKeyCode = event.keyCode
                liveModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift, .function])

                // 捕获快捷键
                if let captured = HotkeyConfiguration.capture(from: event) {
                    if let issue = validation(captured), issue.severity == .error {
                        // 被拒绝的按键：显示红色 + 抖动 + 蜂鸣音
                        isRejected = true
                        capturedHotkey = nil
                        triggerShake()
                        NSSound.beep()

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            isRejected = false
                            liveKeyCode = nil
                            liveModifiers = []
                        }
                        return nil
                    }

                    // 保存捕获的快捷键，等待释放
                    capturedHotkey = captured
                }
                return nil

            } else if event.type == .keyUp {
                // 主键释放
                if event.keyCode == liveKeyCode {
                    liveKeyCode = nil

                    // 如果修饰键也都释放了，保存快捷键
                    if liveModifiers.isEmpty, let captured = capturedHotkey {
                        hotkey = captured
                        feedback = validation(captured)
                        stopRecording()
                    }
                }
                return nil

            } else if event.type == .flagsChanged {
                let newModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift, .function])

                // 修饰键释放
                if newModifiers.isEmpty {
                    liveModifiers = []

                    // 如果主键也释放了，保存快捷键
                    if liveKeyCode == nil, let captured = capturedHotkey {
                        hotkey = captured
                        feedback = validation(captured)
                        stopRecording()
                    }
                } else {
                    liveModifiers = newModifiers

                    // 捕获修饰键作为单键
                    if let captured = HotkeyConfiguration.capture(from: event) {
                        if let issue = validation(captured), issue.severity == .error {
                            isRejected = true
                            capturedHotkey = nil
                            triggerShake()
                            NSSound.beep()

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                isRejected = false
                                liveKeyCode = nil
                                liveModifiers = []
                            }
                            return nil
                        }

                        // 立即保存捕获的修饰键，等待释放
                        capturedHotkey = captured
                    }
                }
                return nil
            }
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        isRejected = false
        liveModifiers = []
        liveKeyCode = nil
        capturedHotkey = nil
        appModel.resumeHotkeys()
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func triggerShake() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) {
            shakeOffset = 10
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) {
                shakeOffset = -10
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) {
                shakeOffset = 5
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) {
                shakeOffset = 0
            }
        }
    }
}

private struct HotkeyDisplay: View {
    let hotkey: HotkeyConfiguration

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(hotkey.keyComponents.enumerated()), id: \.offset) { index, key in
                KeyCapView(label: key, isActive: false)
                if index < hotkey.keyComponents.count - 1 {
                    Text("+")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DVITheme.tertiaryInk)
                }
            }
        }
    }
}

private struct LiveHotkeyDisplay: View {
    let modifiers: NSEvent.ModifierFlags
    let keyCode: UInt16?
    let accent: Color
    let isRejected: Bool

    var body: some View {
        HStack(spacing: 4) {
            if modifiers.contains(.control) {
                KeyCapView(label: "⌃", isActive: true, accent: isRejected ? .red : accent)
                Text("+").font(.system(size: 10, weight: .medium)).foregroundStyle(isRejected ? .red : accent)
            }
            if modifiers.contains(.option) {
                KeyCapView(label: "⌥", isActive: true, accent: isRejected ? .red : accent)
                Text("+").font(.system(size: 10, weight: .medium)).foregroundStyle(isRejected ? .red : accent)
            }
            if modifiers.contains(.shift) {
                KeyCapView(label: "⇧", isActive: true, accent: isRejected ? .red : accent)
                Text("+").font(.system(size: 10, weight: .medium)).foregroundStyle(isRejected ? .red : accent)
            }
            if modifiers.contains(.command) {
                KeyCapView(label: "⌘", isActive: true, accent: isRejected ? .red : accent)
                Text("+").font(.system(size: 10, weight: .medium)).foregroundStyle(isRejected ? .red : accent)
            }
            if modifiers.contains(.function) {
                KeyCapView(label: "fn", isActive: true, accent: isRejected ? .red : accent)
                if keyCode != nil {
                    Text("+").font(.system(size: 10, weight: .medium)).foregroundStyle(isRejected ? .red : accent)
                }
            }

            if let keyCode {
                let keyName = HotkeyFormatter.displayName(forKeyCode: keyCode, modifiers: [])
                KeyCapView(label: keyName, isActive: true, accent: isRejected ? .red : accent)
            } else if modifiers.isEmpty {
                Text("按下按键...")
                    .font(.system(size: 11))
                    .foregroundStyle(DVITheme.secondaryInk)
            }
        }
    }
}

private struct KeyCapView: View {
    let label: String
    var isActive: Bool = false
    var accent: Color = .accentColor

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(isActive ? accent : DVITheme.ink)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                isActive
                    ? accent.opacity(0.12)
                    : DVITheme.control
            )
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        isActive
                            ? accent.opacity(0.4)
                            : DVITheme.separator.opacity(0.3),
                        lineWidth: 1
                    )
            )
    }
}

private struct HotkeyConflictIndicator: View {
    let hotkey: HotkeyConfiguration
    let otherHotkey: HotkeyConfiguration?
    @State private var showPopover = false

    var conflictInfo: HotkeyConflictInfo {
        hotkey.conflictInfo(comparing: otherHotkey)
    }

    var body: some View {
        Group {
            if conflictInfo.severity != .none {
                Button {
                    showPopover.toggle()
                } label: {
                    Image(systemName: iconName)
                        .font(.system(size: 13))
                        .foregroundStyle(iconColor)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showPopover, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        if let title = conflictInfo.title {
                            HStack(spacing: 6) {
                                Image(systemName: iconName)
                                    .font(.system(size: 12))
                                    .foregroundStyle(iconColor)
                                Text(title)
                                    .font(.system(size: 13, weight: .semibold))
                            }
                        }

                        if !conflictInfo.details.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(conflictInfo.details, id: \.self) { detail in
                                    HStack(alignment: .top, spacing: 6) {
                                        Text("•")
                                            .font(.system(size: 11))
                                            .foregroundStyle(DVITheme.secondaryInk)
                                        Text(detail)
                                            .font(.system(size: 11))
                                            .foregroundStyle(DVITheme.secondaryInk)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: 280)
                }
                .help(conflictInfo.title ?? "查看冲突详情")
            } else {
                Color.clear.frame(width: 0, height: 0)
            }
        }
    }

    private var iconName: String {
        switch conflictInfo.severity {
        case .error:
            return "exclamationmark.triangle.fill"
        case .warning:
            return "info.circle.fill"
        case .none:
            return ""
        }
    }

    private var iconColor: Color {
        switch conflictInfo.severity {
        case .error:
            return DVITheme.caution
        case .warning:
            return .blue
        case .none:
            return .clear
        }
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

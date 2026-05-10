import AppKit
import Combine
import Foundation
import os

@MainActor
final class VoiceInputAppModel: ObservableObject {
    private static let logger = Logger(subsystem: "com.end.DesktopVoiceInput", category: "VoiceInputAppModel")

    private enum ActiveTriggerKind {
        case holdToTalk
        case toggleToTalk
    }

    var settings: AppSettings
    let permissionCoordinator: PermissionCoordinator
    let previewState: PreviewState
    let overlayController: PreviewOverlayController
    let orchestrator: RecognitionOrchestrator
    let hotkeyManager: HotkeyManager
    let hotwordStore: HotwordStore

    @Published private(set) var lastInsertionResult: InsertionResult?
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var appearanceRevision = UUID()
    @Published private(set) var requestedSettingsTab: SettingsTab = .general
    @Published private(set) var settingsFocusRequest = UUID()
    @Published private(set) var settingsOpenRequest: UUID?

    private var cancellables = Set<AnyCancellable>()
    private var activeTriggerKind: ActiveTriggerKind?
    private var isTransitioning = false

    init() {
        let settings = AppSettings()
        let permissionCoordinator = PermissionCoordinator()
        let previewState = PreviewState()
        let overlayController = PreviewOverlayController(previewState: previewState, settings: settings)
        let providerFactory = ProviderFactory(settings: settings)
        let postProcessor = TranscriptPostProcessor()
        let hotwordStore = HotwordStore()
        let smartPostProcessor = SmartPostProcessor(settings: settings, hotwordStore: hotwordStore)
        let textInsertionService = TextInsertionService()
        let audioCaptureEngine = AudioCaptureEngine()

        // 预热音频引擎，减少首次启动延迟
        audioCaptureEngine.prewarm()

        let orchestrator = RecognitionOrchestrator(
            settings: settings,
            permissionCoordinator: permissionCoordinator,
            previewState: previewState,
            audioCaptureEngine: audioCaptureEngine,
            providerFactory: providerFactory,
            postProcessor: postProcessor,
            smartPostProcessor: smartPostProcessor,
            textInsertionService: textInsertionService
        )

        self.settings = settings
        self.permissionCoordinator = permissionCoordinator
        self.previewState = previewState
        self.overlayController = overlayController
        self.hotwordStore = hotwordStore
        self.orchestrator = orchestrator
        self.hotkeyManager = HotkeyManager(settings: settings)

        bind()
        applyAppearance(settings.appearancePreference)

        Task {
            await refreshPermissionsAndUpdateHotkeys(promptForSystemDialogs: false)
            openSettingsWindowForAppEntry()
        }
    }

    private func bind() {
        previewState.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        permissionCoordinator.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        settings.$appearancePreference
            .receive(on: RunLoop.main)
            .sink { [weak self] preference in
                self?.applyAppearance(preference)
            }
            .store(in: &cancellables)

        DistributedNotificationCenter.default()
            .publisher(for: Notification.Name("AppleInterfaceThemeChangedNotification"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.applyAppearance(self.settings.appearancePreference)
            }
            .store(in: &cancellables)

        hotkeyManager.onHoldPress = { [weak self] in
            guard let self else { return }
            Task { await self.beginCaptureUsingHoldHotkey() }
        }

        hotkeyManager.onHoldRelease = { [weak self] in
            guard let self else { return }
            Task { await self.endCaptureUsingHoldHotkey() }
        }

        hotkeyManager.onTogglePress = { [weak self] in
            guard let self else { return }
            Task { await self.toggleCaptureUsingToggleHotkey() }
        }

        Publishers.CombineLatest(settings.$holdToTalkHotkey, settings.$toggleToTalkHotkey)
            .dropFirst()
            .sink { [weak self] _ in
                self?.reloadHotkeysIfReady()
            }
            .store(in: &cancellables)

        orchestrator.$lastInsertionResult
            .receive(on: RunLoop.main)
            .assign(to: &$lastInsertionResult)

        orchestrator.$lastErrorMessage
            .receive(on: RunLoop.main)
            .assign(to: &$lastErrorMessage)

        orchestrator.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        orchestrator.$isSessionRunning
            .dropFirst()
            .sink { [weak self] isRunning in
                guard let self else { return }
                if !isRunning {
                    self.activeTriggerKind = nil
                    self.isTransitioning = false
                    self.hotkeyManager.notifySessionEnded()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.refreshPermissionsAndUpdateHotkeys(promptForSystemDialogs: false) }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .voiceInputAppReopenRequested)
            .sink { [weak self] _ in
                guard let self else { return }
                Task {
                    await self.refreshPermissionsAndUpdateHotkeys(promptForSystemDialogs: false)
                    self.openSettingsWindowForAppEntry()
                }
            }
            .store(in: &cancellables)

        // 监听窗口焦点变化，用户从系统设置返回时立即检查
        NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.refreshPermissionsAndUpdateHotkeys(promptForSystemDialogs: false) }
            }
            .store(in: &cancellables)
    }

    func openSystemSettings() {
        openFirstAvailableSystemSettingsURL([
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension",
            "x-apple.systempreferences:com.apple.preference.security?Privacy",
            "x-apple.systempreferences:com.apple.preference.security"
        ])
    }

    func openSettingsWindow() {
        AppDelegate.shared?.openSettingsWindow()
    }

    func bringSettingsWindowForward() {
        AppDelegate.shared?.openSettingsWindow()
    }

    func prepareSettingsWindow(tab: SettingsTab) {
        requestedSettingsTab = tab
        settingsFocusRequest = UUID()
    }

    func showSettingsWindow(tab: SettingsTab) {
        prepareSettingsWindow(tab: tab)
        AppDelegate.shared?.openSettingsWindow(tab: tab)
    }

    func openSystemSettings(for permission: AppPermissionKind) {
        openFirstAvailableSystemSettingsURL(permission.settingsURLStrings + permission.fallbackSettingsURLStrings)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            NSWorkspace.shared.runningApplications
                .first { $0.bundleIdentifier == "com.apple.systempreferences" }?
                .activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        }
    }

    func requestPermissions() {
        showSettingsWindow(tab: .permissions)
    }

    func refreshPermissionStatus() async {
        await refreshPermissionsAndUpdateHotkeys(promptForSystemDialogs: false)
    }

    var missingPermissions: [AppPermissionKind] {
        permissionCoordinator.missingPermissions(for: settings.preferredMode)
    }

    var hasMissingPermissions: Bool {
        !missingPermissions.isEmpty
    }

    func actionLabel(for permission: AppPermissionKind) -> String {
        let state = permissionCoordinator.state(for: permission)
        if permission.canPromptInApp && state == .notDetermined {
            return "立即申请"
        }
        return "前往设置"
    }

    func handlePermissionAction(_ permission: AppPermissionKind) {
        prepareSettingsWindow(tab: .permissions)
        let state = permissionCoordinator.state(for: permission)
        if permission == .accessibility {
            _ = permissionCoordinator.refreshAccessibility(prompt: true)
            openSystemSettings(for: permission)
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                await refreshPermissionsAndUpdateHotkeys(promptForSystemDialogs: false)
            }
            return
        }

        if permission == .inputMonitoring {
            _ = permissionCoordinator.refreshInputMonitoring(prompt: true)
            openSystemSettings(for: permission)
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                await refreshPermissionsAndUpdateHotkeys(promptForSystemDialogs: false)
            }
            return
        }

        if permission.canPromptInApp && state == .notDetermined {
            // 只请求当前这个权限
            Task {
                switch permission {
                case .microphone:
                    _ = await permissionCoordinator.refreshMicrophone(prompt: true)
                case .speechRecognition:
                    _ = await permissionCoordinator.refreshSpeechRecognition(prompt: true)
                case .accessibility:
                    _ = permissionCoordinator.refreshAccessibility(prompt: true)
                case .inputMonitoring:
                    _ = permissionCoordinator.refreshInputMonitoring(prompt: true)
                }
                await refreshPermissionsAndUpdateHotkeys(promptForSystemDialogs: false)
                showSettingsWindow(tab: .permissions)
            }
        } else {
            openSystemSettings(for: permission)
            prepareSettingsWindow(tab: .permissions)
        }
    }

    func quit() {
        NSApp.terminate(nil)
    }

    func suspendHotkeys() {
        hotkeyManager.suspend()
    }

    func resumeHotkeys() {
        hotkeyManager.resume()
    }

    private func applyAppearance(_ preference: AppearancePreference) {
        NSApp.appearance = preference.nsAppearance
        for window in NSApp.windows {
            window.appearance = preference.nsAppearance
            window.contentView?.appearance = preference.nsAppearance
            window.contentView?.needsDisplay = true
        }
        appearanceRevision = UUID()
    }

    private func refreshPermissionsAndUpdateHotkeys(promptForSystemDialogs: Bool) async {
        await permissionCoordinator.refreshAll(promptForSystemDialogs: promptForSystemDialogs)
        updateHotkeyMonitoring()
    }

    private func updateHotkeyMonitoring() {
        if hotkeyPermissionsReady {
            Self.logger.debug("Hotkey permissions ready; ensuring monitor is active")
            hotkeyManager.start()
        } else {
            Self.logger.debug("Hotkey permissions missing; stopping monitor")
            hotkeyManager.stop()
        }
    }

    private func reloadHotkeysIfReady() {
        if hotkeyPermissionsReady {
            Self.logger.info("Reloading hotkeys after configuration change")
            hotkeyManager.reloadConfiguration()
        } else {
            Self.logger.debug("Hotkey configuration changed while permissions are missing")
            hotkeyManager.stop()
        }
    }

    private var hotkeyPermissionsReady: Bool {
        permissionCoordinator.inputMonitoring.isUsable && permissionCoordinator.accessibility.isUsable
    }

    private func openSettingsWindowForAppEntry() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self else { return }
            let tab: SettingsTab = self.hasMissingPermissions ? .permissions : .general
            self.showSettingsWindow(tab: tab)
        }
    }

    private func openFirstAvailableSystemSettingsURL(_ urlStrings: [String]) {
        for urlString in urlStrings {
            guard let url = URL(string: urlString), NSWorkspace.shared.open(url) else {
                continue
            }
            return
        }

        NSWorkspace.shared.launchApplication("System Settings")
    }

    private func beginCaptureUsingHoldHotkey() async {
        guard activeTriggerKind == nil, !orchestrator.isSessionRunning, !isTransitioning else {
            Self.logger.info("Hold hotkey begin ignored. activeTrigger=\(String(describing: self.activeTriggerKind), privacy: .public) isSessionRunning=\(self.orchestrator.isSessionRunning, privacy: .public) isTransitioning=\(self.isTransitioning, privacy: .public)")
            return
        }
        Self.logger.info("Hold hotkey begin accepted")
        activeTriggerKind = .holdToTalk
        isTransitioning = true
        hotkeyManager.notifySessionStarted()
        await orchestrator.beginCapture()
        isTransitioning = false
        if !orchestrator.isSessionRunning {
            Self.logger.info("Hold hotkey begin ended before session became running")
            activeTriggerKind = nil
            hotkeyManager.notifySessionEnded()
        }
    }

    private func endCaptureUsingHoldHotkey() async {
        guard activeTriggerKind == .holdToTalk else {
            Self.logger.info("Hold hotkey end ignored. activeTrigger=\(String(describing: self.activeTriggerKind), privacy: .public)")
            return
        }
        Self.logger.info("Hold hotkey end accepted")
        await orchestrator.endCapture()
    }

    private func toggleCaptureUsingToggleHotkey() async {
        guard !isTransitioning else {
            Self.logger.info("Toggle hotkey ignored because capture transition is in progress")
            return
        }

        if activeTriggerKind == .toggleToTalk || (activeTriggerKind == nil && orchestrator.isSessionRunning) {
            Self.logger.info("Toggle hotkey ending active capture")
            activeTriggerKind = .toggleToTalk
            await orchestrator.endCapture()
            return
        }

        guard activeTriggerKind == nil, !orchestrator.isSessionRunning else {
            Self.logger.info("Toggle hotkey begin ignored. activeTrigger=\(String(describing: self.activeTriggerKind), privacy: .public) isSessionRunning=\(self.orchestrator.isSessionRunning, privacy: .public)")
            return
        }
        Self.logger.info("Toggle hotkey begin accepted")
        activeTriggerKind = .toggleToTalk
        isTransitioning = true
        hotkeyManager.notifySessionStarted()
        await orchestrator.beginCapture()
        isTransitioning = false
        if !orchestrator.isSessionRunning {
            Self.logger.info("Toggle hotkey begin ended before session became running")
            activeTriggerKind = nil
            hotkeyManager.notifySessionEnded()
        }
    }
}

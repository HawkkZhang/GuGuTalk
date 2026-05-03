import AppKit
import Combine
import Foundation

@MainActor
final class VoiceInputAppModel: ObservableObject {
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
            await permissionCoordinator.refreshAll(promptForSystemDialogs: false)
            hotkeyManager.start()
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
                self?.hotkeyManager.reloadConfiguration()
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
                Task { await self.permissionCoordinator.refreshAll(promptForSystemDialogs: false) }
            }
            .store(in: &cancellables)
    }

    func openSystemSettings() {
        NSApp.activate(ignoringOtherApps: true)
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func openSystemSettings(for permission: AppPermissionKind) {
        NSApp.activate(ignoringOtherApps: true)
        guard let url = URL(string: permission.settingsURLString) else {
            openSystemSettings()
            return
        }
        NSWorkspace.shared.open(url)
    }

    func requestPermissions() {
        NSApp.activate(ignoringOtherApps: true)

        Task {
            await permissionCoordinator.requestMissingPermissions(for: settings.preferredMode)
            await permissionCoordinator.refreshAll(promptForSystemDialogs: false)
        }
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
        let state = permissionCoordinator.state(for: permission)
        if permission.canPromptInApp && state == .notDetermined {
            requestPermissions()
        } else {
            openSystemSettings(for: permission)
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

    private func beginCaptureUsingHoldHotkey() async {
        guard activeTriggerKind == nil, !orchestrator.isSessionRunning, !isTransitioning else { return }
        activeTriggerKind = .holdToTalk
        isTransitioning = true
        hotkeyManager.notifySessionStarted()
        await orchestrator.beginCapture()
        isTransitioning = false
        if !orchestrator.isSessionRunning {
            activeTriggerKind = nil
            hotkeyManager.notifySessionEnded()
        }
    }

    private func endCaptureUsingHoldHotkey() async {
        guard activeTriggerKind == .holdToTalk else { return }
        await orchestrator.endCapture()
    }

    private func toggleCaptureUsingToggleHotkey() async {
        guard !isTransitioning else { return }

        if activeTriggerKind == .toggleToTalk || (activeTriggerKind == nil && orchestrator.isSessionRunning) {
            activeTriggerKind = .toggleToTalk
            await orchestrator.endCapture()
            return
        }

        guard activeTriggerKind == nil, !orchestrator.isSessionRunning else { return }
        activeTriggerKind = .toggleToTalk
        isTransitioning = true
        hotkeyManager.notifySessionStarted()
        await orchestrator.beginCapture()
        isTransitioning = false
        if !orchestrator.isSessionRunning {
            activeTriggerKind = nil
            hotkeyManager.notifySessionEnded()
        }
    }
}

import ApplicationServices
import AVFoundation
import Combine
import Foundation
import Speech

@MainActor
final class PermissionCoordinator: ObservableObject {
    @Published private(set) var microphone: PermissionState = .notDetermined
    @Published private(set) var speechRecognition: PermissionState = .notDetermined
    @Published private(set) var accessibility: PermissionState = .notDetermined
    @Published private(set) var inputMonitoring: PermissionState = .notDetermined

    func refreshAll(promptForSystemDialogs: Bool) async {
        microphone = await refreshMicrophone(prompt: promptForSystemDialogs)
        speechRecognition = await refreshSpeechRecognition(prompt: promptForSystemDialogs)
        accessibility = refreshAccessibility(prompt: promptForSystemDialogs)
        inputMonitoring = refreshInputMonitoring(prompt: promptForSystemDialogs)
    }

    func state(for permission: AppPermissionKind) -> PermissionState {
        switch permission {
        case .microphone:
            microphone
        case .speechRecognition:
            speechRecognition
        case .accessibility:
            accessibility
        case .inputMonitoring:
            inputMonitoring
        }
    }

    func missingPermissions(for mode: RecognitionMode) -> [AppPermissionKind] {
        var required: [AppPermissionKind] = [.microphone, .accessibility, .inputMonitoring]

        if mode == .auto || mode == .local {
            required.insert(.speechRecognition, at: 1)
        }

        return required.filter { !state(for: $0).isUsable }
    }

    func requestMissingPermissions(for mode: RecognitionMode) async {
        for permission in missingPermissions(for: mode) {
            switch permission {
            case .microphone:
                microphone = await refreshMicrophone(prompt: true)
            case .speechRecognition:
                speechRecognition = await refreshSpeechRecognition(prompt: true)
            case .accessibility:
                accessibility = refreshAccessibility(prompt: true)
            case .inputMonitoring:
                inputMonitoring = refreshInputMonitoring(prompt: true)
            }
        }
    }

    func allRequiredForCaptureReady() -> Bool {
        microphone.isUsable && accessibility.isUsable && inputMonitoring.isUsable
    }

    private func refreshMicrophone(prompt: Bool) async -> PermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .authorized
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            guard prompt else { return .notDetermined }
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            return granted ? .authorized : .denied
        @unknown default:
            return .unsupported
        }
    }

    private func refreshSpeechRecognition(prompt: Bool) async -> PermissionState {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return .authorized
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            guard prompt else { return .notDetermined }
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    switch status {
                    case .authorized:
                        continuation.resume(returning: .authorized)
                    case .denied, .restricted:
                        continuation.resume(returning: .denied)
                    case .notDetermined:
                        continuation.resume(returning: .notDetermined)
                    @unknown default:
                        continuation.resume(returning: .unsupported)
                    }
                }
            }
        @unknown default:
            return .unsupported
        }
    }

    private func refreshAccessibility(prompt: Bool) -> PermissionState {
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options) ? .authorized : .denied
    }

    private func refreshInputMonitoring(prompt: Bool) -> PermissionState {
        if CGPreflightListenEventAccess() {
            return .authorized
        }

        if prompt {
            let granted = CGRequestListenEventAccess()
            return granted ? .authorized : .denied
        }

        return .denied
    }
}

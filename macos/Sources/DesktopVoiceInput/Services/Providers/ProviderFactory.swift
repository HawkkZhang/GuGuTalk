import Foundation

@MainActor
final class ProviderFactory {
    private unowned let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    func resolveProviders() -> [ProviderSelection] {
        let config = settings.recognitionConfig

        switch config.mode {
        case .auto:
            var providers: [ProviderSelection] = [ProviderSelection(mode: .local, provider: LocalSpeechProvider())]

            if config.doubaoCredentials.isConfigured {
                providers.append(ProviderSelection(mode: .doubao, provider: DoubaoSpeechProvider()))
            }

            if config.qwenCredentials.isConfigured {
                providers.append(ProviderSelection(mode: .qwen, provider: QwenSpeechProvider()))
            }

            return providers
        case .local:
            return [ProviderSelection(mode: .local, provider: LocalSpeechProvider())]
        case .doubao:
            return [ProviderSelection(mode: .doubao, provider: DoubaoSpeechProvider())]
        case .qwen:
            return [ProviderSelection(mode: .qwen, provider: QwenSpeechProvider())]
        }
    }
}

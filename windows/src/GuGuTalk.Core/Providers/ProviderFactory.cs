using GuGuTalk.Core.Models;
using GuGuTalk.Core.Settings;

namespace GuGuTalk.Core.Providers;

public sealed class ProviderFactory
{
    private readonly AppSettings _settings;

    public ProviderFactory(AppSettings settings)
    {
        _settings = settings;
    }

    public List<ProviderSelection> ResolveProviders()
    {
        var selections = new List<ProviderSelection>();

        switch (_settings.PreferredMode)
        {
            case RecognitionMode.Local:
                // Local provider added by app layer (GuGuTalk.LocalAsr)
                break;
            case RecognitionMode.Doubao:
                if (_settings.DoubaoCredentials.IsConfigured)
                    selections.Add(new ProviderSelection(RecognitionMode.Doubao, new DoubaoSpeechProvider()));
                if (_settings.QwenCredentials.IsConfigured)
                    selections.Add(new ProviderSelection(RecognitionMode.Qwen, new QwenSpeechProvider()));
                break;
            case RecognitionMode.Qwen:
                if (_settings.QwenCredentials.IsConfigured)
                    selections.Add(new ProviderSelection(RecognitionMode.Qwen, new QwenSpeechProvider()));
                if (_settings.DoubaoCredentials.IsConfigured)
                    selections.Add(new ProviderSelection(RecognitionMode.Doubao, new DoubaoSpeechProvider()));
                break;
        }

        return selections;
    }
}

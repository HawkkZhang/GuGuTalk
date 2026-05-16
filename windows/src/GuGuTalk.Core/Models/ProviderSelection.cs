namespace GuGuTalk.Core.Models;

public sealed record ProviderSelection(
    RecognitionMode Mode,
    Core.ISpeechProvider Provider
);

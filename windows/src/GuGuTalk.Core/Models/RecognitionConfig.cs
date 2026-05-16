namespace GuGuTalk.Core.Models;

public sealed record RecognitionConfig(
    string LanguageCode,
    double SampleRate,
    RecognitionMode Mode,
    bool PartialResultsEnabled,
    EndpointingPolicy Endpointing,
    DoubaoCredentials DoubaoCredentials,
    QwenCredentials QwenCredentials
);

public enum EndpointingPolicy
{
    VoiceActivityDetection,
    Manual
}

public sealed record DoubaoCredentials(
    string AppId,
    string AccessKey,
    string ResourceId,
    string Endpoint
)
{
    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(AppId)
        && !string.IsNullOrWhiteSpace(AccessKey)
        && !string.IsNullOrWhiteSpace(ResourceId)
        && !string.IsNullOrWhiteSpace(Endpoint);
}

public sealed record QwenCredentials(
    string ApiKey,
    string Model,
    string Endpoint
)
{
    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(ApiKey)
        && !string.IsNullOrWhiteSpace(Model)
        && !string.IsNullOrWhiteSpace(Endpoint);
}

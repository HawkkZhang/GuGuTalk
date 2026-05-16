namespace GuGuTalk.Core.Models;

public sealed record LLMProviderConfig(
    string Endpoint,
    string ApiKey,
    string Model
)
{
    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(Endpoint)
        && !string.IsNullOrWhiteSpace(ApiKey)
        && !string.IsNullOrWhiteSpace(Model);

    public static LLMProviderConfig Empty => new("", "", "");
}

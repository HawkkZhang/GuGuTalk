namespace GuGuTalk.Core.Models;

public sealed record PostProcessingConfig(
    bool Enabled,
    PunctuationMode PunctuationMode,
    string? ActivePrompt
);

public enum PunctuationMode
{
    Smart,
    Remove,
    SpaceReplace,
    RemoveTrailingPeriod
}

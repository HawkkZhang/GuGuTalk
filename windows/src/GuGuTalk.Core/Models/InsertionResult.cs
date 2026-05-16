namespace GuGuTalk.Core.Models;

public sealed record InsertionResult(
    InsertionMethod Method,
    string? TargetAppName,
    bool Succeeded,
    string? FailureReason
);

public enum InsertionMethod
{
    UIAutomation,
    SendInput,
    Clipboard,
    Failed
}

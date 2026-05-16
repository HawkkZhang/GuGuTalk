namespace GuGuTalk.Core.Models;

public enum PermissionKind
{
    Microphone,
    KeyboardHook
}

public enum PermissionStatus
{
    Unknown,
    Granted,
    Denied,
    Restricted
}

public sealed record PermissionState(PermissionKind Kind, PermissionStatus Status);

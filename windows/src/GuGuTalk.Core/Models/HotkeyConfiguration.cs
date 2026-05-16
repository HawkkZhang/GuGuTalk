namespace GuGuTalk.Core.Models;

public sealed record HotkeyConfiguration(
    int VirtualKey,
    ModifierKeys Modifiers,
    string DisplayName
)
{
    public static HotkeyConfiguration DefaultHold => new(0xC0, ModifierKeys.Control, "Ctrl+`");
    public static HotkeyConfiguration DefaultToggle => new(0x20, ModifierKeys.Alt, "Alt+Space");
}

[Flags]
public enum ModifierKeys
{
    None = 0,
    Alt = 1,
    Control = 2,
    Shift = 4,
    Win = 8
}

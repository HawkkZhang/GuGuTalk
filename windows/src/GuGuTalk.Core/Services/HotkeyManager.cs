using GuGuTalk.Core.Models;
using Serilog;

namespace GuGuTalk.Core.Services;

public sealed class HotkeyManager : IHotkeyManager
{
    private static readonly ILogger Logger = Log.ForContext<HotkeyManager>();

    public event Action? OnHoldPress;
    public event Action? OnHoldRelease;
    public event Action? OnTogglePress;

    private readonly Settings.AppSettings _settings;
    private bool _isHoldPressed;
    private bool _isTogglePressed;
    private bool _isSuspended;

    public HotkeyManager(Settings.AppSettings settings)
    {
        _settings = settings;
    }

    public void Start()
    {
        Logger.Information("Hotkey manager started. Hold={Hold} Toggle={Toggle}",
            _settings.HoldToTalkHotkey.DisplayName, _settings.ToggleToTalkHotkey.DisplayName);
    }

    public void Stop()
    {
        _isHoldPressed = false;
        _isTogglePressed = false;
        Logger.Information("Hotkey manager stopped");
    }

    public void Suspend()
    {
        _isSuspended = true;
        _isHoldPressed = false;
        _isTogglePressed = false;
        Logger.Information("Hotkey manager suspended");
    }

    public void Resume()
    {
        _isSuspended = false;
        Logger.Information("Hotkey manager resumed");
    }

    public void ReloadConfiguration()
    {
        _isHoldPressed = false;
        _isTogglePressed = false;
        Logger.Information("Hotkey configuration reloaded");
    }

    public void HandleKeyEvent(int vkCode, bool isDown, ModifierKeys modifiers)
    {
        if (_isSuspended) return;

        var holdHotkey = _settings.HoldToTalkHotkey;
        var toggleHotkey = _settings.ToggleToTalkHotkey;

        if (isDown)
        {
            if (_settings.ToggleToTalkEnabled
                && vkCode == toggleHotkey.VirtualKey
                && MatchesModifiers(modifiers, toggleHotkey.Modifiers)
                && !_isTogglePressed)
            {
                _isTogglePressed = true;
                Logger.Information("Toggle hotkey pressed. vk={VK} mods={Mods}", vkCode, modifiers);
                OnTogglePress?.Invoke();
                return;
            }

            if (_settings.HoldToTalkEnabled
                && vkCode == holdHotkey.VirtualKey
                && MatchesModifiers(modifiers, holdHotkey.Modifiers)
                && !_isHoldPressed)
            {
                _isHoldPressed = true;
                Logger.Information("Hold hotkey pressed. vk={VK} mods={Mods}", vkCode, modifiers);
                OnHoldPress?.Invoke();
                return;
            }
        }
        else
        {
            if (_isTogglePressed && vkCode == toggleHotkey.VirtualKey)
            {
                _isTogglePressed = false;
                Logger.Debug("Toggle hotkey released");
                return;
            }

            if (_isHoldPressed && vkCode == holdHotkey.VirtualKey)
            {
                _isHoldPressed = false;
                Logger.Information("Hold hotkey released");
                OnHoldRelease?.Invoke();
                return;
            }
        }
    }

    private static bool MatchesModifiers(ModifierKeys actual, ModifierKeys expected) =>
        actual == expected;
}

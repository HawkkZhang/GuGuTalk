using GuGuTalk.Core.Models;

namespace GuGuTalk.Core.Services;

public interface IHotkeyManager
{
    event Action? OnHoldPress;
    event Action? OnHoldRelease;
    event Action? OnTogglePress;

    void Start();
    void Stop();
    void Suspend();
    void Resume();
    void ReloadConfiguration();
}

using GuGuTalk.Core.Models;
using Serilog;

namespace GuGuTalk.Core.Services;

public sealed class PermissionCoordinator : IPermissionCoordinator
{
    private static readonly ILogger Logger = Log.ForContext<PermissionCoordinator>();

    private readonly List<PermissionState> _states = [];

    public IReadOnlyList<PermissionState> CurrentStates => _states;

    public Task RefreshAllAsync()
    {
        _states.Clear();

        // Microphone: try to enumerate capture devices
        var micStatus = CheckMicrophonePermission();
        _states.Add(new PermissionState(PermissionKind.Microphone, micStatus));

        // Keyboard hook: generally always available on Windows
        _states.Add(new PermissionState(PermissionKind.KeyboardHook, PermissionStatus.Granted));

        Logger.Information("Permissions refreshed. Mic={Mic}", micStatus);
        return Task.CompletedTask;
    }

    public bool AllRequiredReady() =>
        _states.All(s => s.Status == PermissionStatus.Granted);

    private static PermissionStatus CheckMicrophonePermission()
    {
        try
        {
            using var enumerator = new NAudio.CoreAudioApi.MMDeviceEnumerator();
            var device = enumerator.GetDefaultAudioEndpoint(
                NAudio.CoreAudioApi.DataFlow.Capture,
                NAudio.CoreAudioApi.Role.Communications);
            return device is not null ? PermissionStatus.Granted : PermissionStatus.Denied;
        }
        catch
        {
            return PermissionStatus.Denied;
        }
    }
}

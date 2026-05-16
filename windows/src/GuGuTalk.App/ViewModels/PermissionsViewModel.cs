using CommunityToolkit.Mvvm.ComponentModel;
using GuGuTalk.Core.Models;
using GuGuTalk.Core.Services;

namespace GuGuTalk.App.ViewModels;

public partial class PermissionsViewModel : ObservableObject
{
    private readonly IPermissionCoordinator _coordinator;

    [ObservableProperty] private PermissionStatus _microphoneStatus = PermissionStatus.Unknown;
    [ObservableProperty] private PermissionStatus _keyboardHookStatus = PermissionStatus.Unknown;
    [ObservableProperty] private bool _allReady;

    public PermissionsViewModel(IPermissionCoordinator coordinator)
    {
        _coordinator = coordinator;
    }

    public async Task RefreshAsync()
    {
        await _coordinator.RefreshAllAsync();
        foreach (var state in _coordinator.CurrentStates)
        {
            switch (state.Kind)
            {
                case PermissionKind.Microphone:
                    MicrophoneStatus = state.Status;
                    break;
                case PermissionKind.KeyboardHook:
                    KeyboardHookStatus = state.Status;
                    break;
            }
        }
        AllReady = _coordinator.AllRequiredReady();
    }

    public string MicrophoneDescription => MicrophoneStatus switch
    {
        PermissionStatus.Granted => "麦克风权限已授予",
        PermissionStatus.Denied => "麦克风权限被拒绝。请在 Windows 设置 > 隐私 > 麦克风 中允许此应用访问。",
        _ => "正在检查麦克风权限..."
    };

    public string KeyboardHookDescription => KeyboardHookStatus switch
    {
        PermissionStatus.Granted => "全局热键可用",
        PermissionStatus.Denied => "全局热键被安全软件拦截。请将 GuGuTalk 添加到白名单。",
        _ => "正在检查热键权限..."
    };
}

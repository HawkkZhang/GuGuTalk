using GuGuTalk.Core.Models;

namespace GuGuTalk.Core.Services;

public interface IPermissionCoordinator
{
    IReadOnlyList<PermissionState> CurrentStates { get; }
    Task RefreshAllAsync();
    bool AllRequiredReady();
}

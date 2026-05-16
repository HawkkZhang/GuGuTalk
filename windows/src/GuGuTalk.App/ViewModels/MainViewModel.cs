using CommunityToolkit.Mvvm.ComponentModel;

namespace GuGuTalk.App.ViewModels;

public partial class MainViewModel : ObservableObject
{
    [ObservableProperty]
    private bool _isSessionRunning;

    [ObservableProperty]
    private string? _lastErrorMessage;
}

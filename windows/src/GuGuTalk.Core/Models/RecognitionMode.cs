namespace GuGuTalk.Core.Models;

public enum RecognitionMode
{
    Local,
    Doubao,
    Qwen
}

public static class RecognitionModeExtensions
{
    public static string Title(this RecognitionMode mode) => mode switch
    {
        RecognitionMode.Local => "本地",
        RecognitionMode.Doubao => "豆包",
        RecognitionMode.Qwen => "千问",
        _ => mode.ToString()
    };
}

using FlaUI.Core.AutomationElements;
using FlaUI.UIA3;
using GuGuTalk.Core.Interop;
using GuGuTalk.Core.Models;
using Serilog;

namespace GuGuTalk.Core.Services;

public sealed class TextInsertionService : ITextInsertionService
{
    private static readonly ILogger Logger = Log.ForContext<TextInsertionService>();

    private static readonly HashSet<string> WeChatProcessNames = new(StringComparer.OrdinalIgnoreCase)
    {
        "WeChat", "WeChatAppEx", "Weixin"
    };

    public InsertionResult Insert(string text)
    {
        if (string.IsNullOrEmpty(text))
            return new InsertionResult(InsertionMethod.Failed, null, false, "文本为空");

        var (title, processName) = NativeMethods.GetForegroundWindowInfo();
        Logger.Information("开始插入文本，目标: {Title} ({Process})，长度: {Len}",
            title ?? "未知", processName ?? "未知", text.Length);

        bool isWeChat = processName is not null && WeChatProcessNames.Contains(processName);

        if (isWeChat)
        {
            Logger.Information("微信稳定插入策略");
            var uiaResult = TryUIAutomation(text, title);
            if (uiaResult is not null) return uiaResult;

            if (TrySendInput(text))
                return new InsertionResult(InsertionMethod.SendInput, title, true, null);

            if (TryClipboard(text))
                return new InsertionResult(InsertionMethod.Clipboard, title, true, null);

            return new InsertionResult(InsertionMethod.Failed, title, false, "无法写入微信");
        }

        if (TryClipboard(text))
        {
            Logger.Information("剪贴板粘贴成功");
            return new InsertionResult(InsertionMethod.Clipboard, title, true, null);
        }

        var defaultUia = TryUIAutomation(text, title);
        if (defaultUia is not null) return defaultUia;

        if (TrySendInput(text))
        {
            Logger.Information("SendInput 插入成功");
            return new InsertionResult(InsertionMethod.SendInput, title, true, null);
        }

        Logger.Error("所有插入方法都失败");
        return new InsertionResult(InsertionMethod.Failed, title, false, "无法写入当前应用，请手动复制预览文本。");
    }

    private static InsertionResult? TryUIAutomation(string text, string? targetApp)
    {
        try
        {
            using var automation = new UIA3Automation();
            var focused = automation.FocusedElement();
            if (focused is null) return null;

            var valuePattern = focused.Patterns.Value.PatternOrDefault;
            if (valuePattern is not null && !valuePattern.IsReadOnly.Value)
            {
                string current = valuePattern.Value.Value ?? "";
                valuePattern.SetValue(current + text);
                Logger.Information("UIAutomation 插入成功");
                return new InsertionResult(InsertionMethod.UIAutomation, targetApp, true, null);
            }

            return null;
        }
        catch (Exception ex)
        {
            Logger.Debug(ex, "UIAutomation 失败");
            return null;
        }
    }

    private static bool TrySendInput(string text)
    {
        try
        {
            return NativeMethods.SendUnicodeText(text);
        }
        catch (Exception ex)
        {
            Logger.Warning(ex, "SendInput 失败");
            return false;
        }
    }

    private static bool TryClipboard(string text)
    {
        try
        {
            string? saved = NativeMethods.GetClipboardText();

            if (!NativeMethods.SetClipboardText(text)) return false;
            Thread.Sleep(50);

            NativeMethods.SendCtrlV();
            Thread.Sleep(150);

            if (saved is not null)
            {
                NativeMethods.SetClipboardText(saved);
            }

            return true;
        }
        catch (Exception ex)
        {
            Logger.Warning(ex, "Clipboard 插入失败");
            return false;
        }
    }
}

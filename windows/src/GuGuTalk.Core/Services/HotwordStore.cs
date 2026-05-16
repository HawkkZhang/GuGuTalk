using System.Text.Json;
using GuGuTalk.Core.Models;
using GuGuTalk.Core.Settings;
using Serilog;

namespace GuGuTalk.Core.Services;

public sealed class HotwordStore
{
    private static readonly ILogger Logger = Log.ForContext<HotwordStore>();
    private static readonly string StoragePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "GuGuTalk", "hotwords.json");

    private List<TextReplacement> _replacements = [];

    public IReadOnlyList<TextReplacement> Replacements => _replacements;
    public bool IsEmpty => _replacements.Count == 0;

    public HotwordStore()
    {
        Load();
    }

    public void Add(string from, string to)
    {
        string trimFrom = from.Trim();
        string trimTo = to.Trim();
        if (string.IsNullOrEmpty(trimFrom) || string.IsNullOrEmpty(trimTo)) return;
        if (_replacements.Any(r => r.Pattern == trimFrom)) return;

        _replacements.Add(new TextReplacement(trimFrom, trimTo));
        _replacements.Sort((a, b) => string.Compare(a.Pattern, b.Pattern, StringComparison.Ordinal));
        Save();
    }

    public void Remove(string from)
    {
        _replacements.RemoveAll(r => r.Pattern == from);
        Save();
    }

    public string ApplyReplacements(string text)
    {
        if (_replacements.Count == 0) return text;

        string result = text;
        var sorted = _replacements.OrderByDescending(r => r.Pattern.Length);
        foreach (var replacement in sorted)
        {
            result = result.Replace(replacement.Pattern, replacement.Replacement, StringComparison.OrdinalIgnoreCase);
        }
        return result;
    }

    private void Load()
    {
        try
        {
            if (File.Exists(StoragePath))
            {
                string json = File.ReadAllText(StoragePath);
                _replacements = JsonSerializer.Deserialize<List<TextReplacement>>(json) ?? [];
            }
        }
        catch (Exception ex)
        {
            Logger.Warning(ex, "Failed to load hotwords");
        }
    }

    private void Save()
    {
        try
        {
            string dir = Path.GetDirectoryName(StoragePath)!;
            Directory.CreateDirectory(dir);
            string json = JsonSerializer.Serialize(_replacements, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(StoragePath, json);
        }
        catch (Exception ex)
        {
            Logger.Warning(ex, "Failed to save hotwords");
        }
    }
}

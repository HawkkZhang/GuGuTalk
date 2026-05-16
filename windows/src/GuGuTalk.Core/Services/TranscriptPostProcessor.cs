using System.Text.RegularExpressions;

namespace GuGuTalk.Core.Services;

public sealed class TranscriptPostProcessor
{
    public string Finalize(string text) => NormalizeSpeechText(text);

    public static string NormalizeSpeechText(string text)
    {
        string value = text.Trim();
        if (string.IsNullOrEmpty(value)) return value;

        // Collapse multiple whitespace to single space
        value = Regex.Replace(value, @"\s+", " ");

        // Remove spaces between CJK characters
        value = Regex.Replace(value, @"(?<=[一-鿿])\s+(?=[一-鿿])", "");

        // Remove spaces after CJK punctuation before CJK characters
        value = Regex.Replace(value, @"(?<=[，。！？；：、])\s+(?=[一-鿿])", "");

        // Remove spaces before CJK punctuation
        value = Regex.Replace(value, @"\s+(?=[，。！？；：、])", "");

        // Remove spaces after opening brackets
        value = Regex.Replace(value, @"(?<=[（《「『【])\s+", "");

        // Remove spaces before closing brackets
        value = Regex.Replace(value, @"\s+(?=[）》」』】])", "");

        return value.Trim();
    }
}

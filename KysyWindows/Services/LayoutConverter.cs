namespace Kysy.Services;

public record LayoutSuggestion(string Original, string Converted, string FromLayout, string ToLayout, string FullReplacement)
{
    public bool IsMeaningful => Converted != Original && Converted.Trim().Length > 0;
}

/// <summary>Detects text typed in the wrong keyboard layout and produces the
/// corrected version, working on the last whitespace-delimited word so it works
/// even when a field's value is a whole buffer (Terminal/console).</summary>
public static class LayoutConverter
{
    public static LayoutSuggestion? Suggest(string fullText)
    {
        if (string.IsNullOrWhiteSpace(fullText)) return null;
        var parts = fullText.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length == 0) return null;
        var word = parts[^1];
        if (word.Length > 120) return null;

        int letters = word.Count(c => IsHebrew(c) || IsLatin(c));
        if (letters < 3) return null;
        int he = word.Count(IsHebrew);
        int en = word.Count(IsLatin);
        if (he == en) return null;
        bool hebrewDominant = he > en;

        var english = LanguageManager.FirstEnglish();
        var other = LanguageManager.FirstNonEnglish();
        if (english is null || other is null) return null;

        string? converted = hebrewDominant
            ? KeyboardLayoutMap.Convert(word, other.Hkl, english.Hkl)
            : KeyboardLayoutMap.Convert(word, english.Hkl, other.Hkl);
        if (string.IsNullOrEmpty(converted)) return null;

        string from = hebrewDominant ? other.Name : english.Name;
        string to = hebrewDominant ? english.Name : other.Name;

        // Replace only the last word in the full value.
        int idx = fullText.LastIndexOf(word, StringComparison.Ordinal);
        string full = idx >= 0
            ? fullText.Remove(idx, word.Length).Insert(idx, converted!)
            : converted!;

        return new LayoutSuggestion(word, converted!, from, to, full);
    }

    public static bool IsHebrew(char c) => c >= 0x0590 && c <= 0x05FF;
    public static bool IsLatin(char c) => (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
}

namespace Kysy.Services;

public record LayoutSuggestion(string Original, string Converted, string FromLayout, string ToLayout, string FullReplacement)
{
    public bool IsMeaningful => Converted != Original && Converted.Trim().Length > 0;

    /// <summary>Keyboard layout (HKL) of the corrected text, so the caller can
    /// switch the input language to it and the user keeps typing correctly.</summary>
    public IntPtr ToHkl { get; init; } = IntPtr.Zero;
}

/// <summary>Detects text typed in the wrong keyboard layout and produces the
/// corrected version. <see cref="Suggest"/> works on the last whitespace-delimited
/// word (safe even when a field's value is a whole buffer, e.g. Terminal/console);
/// <see cref="SuggestPhrase"/> converts an entire multi-word run.</summary>
public static class LayoutConverter
{
    /// <summary>Correct the LAST whitespace-delimited word in <paramref name="fullText"/>.
    /// Used by the panel and as the safe fallback for long/console buffers.</summary>
    public static LayoutSuggestion? Suggest(string fullText)
    {
        if (string.IsNullOrWhiteSpace(fullText)) return null;
        var parts = fullText.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length == 0) return null;
        return Build(parts[^1], fullText);
    }

    /// <summary>Correct an ENTIRE typed phrase — every word, with the spaces
    /// between them preserved ("nrhu dktexh" → both words). Returns null for very
    /// long values (likely a console/document buffer), so the caller falls back to
    /// the last-word path rather than rewriting the whole thing.</summary>
    public static LayoutSuggestion? SuggestPhrase(string phrase)
    {
        if (string.IsNullOrWhiteSpace(phrase)) return null;
        return Build(phrase, phrase);
    }

    /// <summary>Shared core: pick the direction from the letters in <paramref name="unit"/>,
    /// convert the whole unit (spaces and unmapped chars pass through), and splice
    /// it back into <paramref name="fullText"/>.</summary>
    private static LayoutSuggestion? Build(string unit, string fullText)
    {
        if (unit.Length is 0 or > 240) return null;

        int letters = unit.Count(c => IsHebrew(c) || IsLatin(c));
        if (letters < 3) return null;
        int he = unit.Count(IsHebrew);
        int en = unit.Count(IsLatin);
        if (he == en) return null;
        bool hebrewDominant = he > en;

        var english = LanguageManager.FirstEnglish();
        var other = LanguageManager.FirstNonEnglish();
        if (english is null || other is null) return null;

        string? converted = hebrewDominant
            ? KeyboardLayoutMap.Convert(unit, other.Hkl, english.Hkl)
            : KeyboardLayoutMap.Convert(unit, english.Hkl, other.Hkl);
        if (string.IsNullOrEmpty(converted)) return null;

        string from = hebrewDominant ? other.Name : english.Name;
        string to = hebrewDominant ? english.Name : other.Name;
        IntPtr toHkl = hebrewDominant ? english.Hkl : other.Hkl;

        // Splice the converted unit back in place, so we don't wipe the rest of
        // the field (no-op when the unit IS the whole text).
        int idx = unit == fullText ? -1 : fullText.LastIndexOf(unit, StringComparison.Ordinal);
        string full = idx >= 0
            ? fullText.Remove(idx, unit.Length).Insert(idx, converted!)
            : converted!;

        return new LayoutSuggestion(unit, converted!, from, to, full) { ToHkl = toHkl };
    }

    public static bool IsHebrew(char c) => c >= 0x0590 && c <= 0x05FF;
    public static bool IsLatin(char c) => (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
}

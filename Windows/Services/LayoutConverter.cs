namespace Kright.Services;

public record LayoutSuggestion(string Original, string Converted, string FromLayout, string ToLayout, string FullReplacement)
{
    public bool IsMeaningful => Converted != Original && Converted.Trim().Length > 0;

    /// <summary>Keyboard layout (HKL) of the corrected text, so the caller can
    /// switch the input language to it and the user keeps typing correctly.</summary>
    public IntPtr ToHkl { get; init; } = IntPtr.Zero;

    /// <summary>ISO language codes of the text as typed and as corrected — used to
    /// pick the right gibberish-detection model.</summary>
    public string FromLang { get; init; } = "";
    public string ToLang { get; init; } = "";
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

        // Direction by Latin vs ANY non-Latin script, so it works for any
        // installed layout pair (Cyrillic, Greek, Arabic…), not just Hebrew.
        int letters = unit.Count(char.IsLetter);
        if (letters < 3) return null;
        int latin = unit.Count(IsLatin);
        int otherCount = letters - latin;
        if (latin == otherCount) return null;
        bool typedIsLatin = latin > otherCount;

        var english = LanguageManager.FirstEnglish();
        var other = LanguageManager.FirstNonEnglish();
        if (english is null || other is null) return null;

        string? converted = typedIsLatin
            ? KeyboardLayoutMap.Convert(unit, english.Hkl, other.Hkl)   // Latin → the other language
            : KeyboardLayoutMap.Convert(unit, other.Hkl, english.Hkl);  // non-Latin → English
        if (string.IsNullOrEmpty(converted)) return null;

        string from = typedIsLatin ? english.Name : other.Name;
        string to = typedIsLatin ? other.Name : english.Name;
        IntPtr toHkl = typedIsLatin ? other.Hkl : english.Hkl;
        string fromLang = typedIsLatin ? english.Lang : other.Lang;
        string toLang = typedIsLatin ? other.Lang : english.Lang;

        // Splice the converted unit back in place, so we don't wipe the rest of
        // the field (no-op when the unit IS the whole text).
        int idx = unit == fullText ? -1 : fullText.LastIndexOf(unit, StringComparison.Ordinal);
        string full = idx >= 0
            ? fullText.Remove(idx, unit.Length).Insert(idx, converted!)
            : converted!;

        return new LayoutSuggestion(unit, converted!, from, to, full)
            { ToHkl = toHkl, FromLang = fromLang, ToLang = toLang };
    }

    public static bool IsHebrew(char c) => c >= 0x0590 && c <= 0x05FF;
    public static bool IsLatin(char c) => (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
}

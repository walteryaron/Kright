using Kright.Native;

namespace Kright.Services;

public record InputLanguage(IntPtr Hkl, string Name, int LangId, bool IsCurrent)
{
    public bool IsEnglish => (LangId & 0xFF) == 0x09;   // LANG_ENGLISH
}

/// <summary>Enumerates installed keyboard layouts and switches the foreground
/// app's input language (Windows analogue of macOS TIS input sources).</summary>
public static class LanguageManager
{
    public static List<InputLanguage> Enabled()
    {
        int count = NativeMethods.GetKeyboardLayoutList(0, Array.Empty<IntPtr>());
        if (count <= 0) return new();
        var buf = new IntPtr[count];
        NativeMethods.GetKeyboardLayoutList(count, buf);

        var current = CurrentHkl();
        var list = new List<InputLanguage>();
        foreach (var hkl in buf)
        {
            int langId = (int)((long)hkl & 0xFFFF);
            list.Add(new InputLanguage(hkl, NameFor(langId), langId, hkl == current));
        }
        return list;
    }

    public static IntPtr CurrentHkl()
    {
        var hwnd = NativeMethods.GetForegroundWindow();
        uint thread = NativeMethods.GetWindowThreadProcessId(hwnd, out _);
        return NativeMethods.GetKeyboardLayout(thread);
    }

    public static InputLanguage? Current() => Enabled().FirstOrDefault(l => l.IsCurrent);
    public static InputLanguage? FirstEnglish() => Enabled().FirstOrDefault(l => l.IsEnglish);
    public static InputLanguage? FirstNonEnglish() => Enabled().FirstOrDefault(l => !l.IsEnglish);

    /// <summary>Whether a layout types Latin letters (English, French, Spanish,
    /// German…) rather than a non-Latin script (Hebrew, Arabic, Cyrillic…).
    /// Decided from the characters the layout produces, so it's language-agnostic.</summary>
    public static bool IsLatin(IntPtr hkl)
    {
        var map = KeyboardLayoutMap.ForwardMap(hkl);
        uint[] keys = { 0x41, 0x53, 0x44, 0x46, 0x48, 0x47, 0x4A, 0x4B, 0x4C }; // A S D F H G J K L
        var letters = keys
            .Select(vk => map.TryGetValue(vk, out var s) && s.Length > 0 ? s[0] : '\0')
            .Where(char.IsLetter).ToList();
        if (letters.Count == 0) return true;                     // unknown → don't disrupt
        return letters.Count(LayoutConverter.IsLatin) * 2 >= letters.Count;
    }

    /// <summary>First enabled Latin-script layout (prefers English), if any.</summary>
    public static InputLanguage? FirstLatin()
        => Enabled().FirstOrDefault(l => l.IsEnglish && IsLatin(l.Hkl))
           ?? Enabled().FirstOrDefault(l => IsLatin(l.Hkl));

    /// <summary>Switch the foreground window's input language to <paramref name="hkl"/>.</summary>
    public static void Switch(IntPtr hkl)
    {
        var hwnd = NativeMethods.GetForegroundWindow();
        if (hwnd == IntPtr.Zero) return;
        NativeMethods.PostMessage(hwnd, NativeMethods.WM_INPUTLANGCHANGEREQUEST, IntPtr.Zero, hkl);
    }

    public static void SwitchToNext()
    {
        var langs = Enabled();
        if (langs.Count < 2) return;
        int idx = langs.FindIndex(l => l.IsCurrent);
        var next = langs[(idx + 1) % langs.Count];
        Switch(next.Hkl);
    }

    private static string NameFor(int langId)
    {
        try
        {
            var ci = new System.Globalization.CultureInfo(langId & 0xFFFF);
            return ci.TwoLetterISOLanguageName.ToUpperInvariant(); // e.g. EN, HE, RU
        }
        catch { return $"0x{langId:X4}"; }
    }
}

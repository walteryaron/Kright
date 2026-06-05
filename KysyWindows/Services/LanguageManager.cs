using Kysy.Native;

namespace Kysy.Services;

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

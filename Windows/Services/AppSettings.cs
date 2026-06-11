using System.IO;
using System.Text.Json;
using Kright.Native;

namespace Kright.Services;

/// <summary>JSON-backed settings in %APPDATA%\Kright\settings.json.</summary>
public sealed class AppSettings
{
    // Default hotkey: Ctrl+Alt+K (avoids clobbering single-modifier shortcuts).
    public uint HotkeyModifiers { get; set; } = NativeMethods.MOD_CONTROL | NativeMethods.MOD_ALT;
    public uint HotkeyVk { get; set; } = 0x4B; // 'K'
    // On by default: switch to English on email / URL / password fields.
    public bool AutoEnglishOnLatinFields { get; set; } = true;

    /// <summary>Show the Detect tab (developer tool). Hidden by default.</summary>
    public bool DebugMode { get; set; } = false;

    /// <summary>Auto-update consent: null = not asked yet (prompt on first run),
    /// true = check automatically, false = manual only. Mirrors Sparkle's
    /// first-run "Check for updates automatically?" prompt on macOS.</summary>
    public bool? AutoUpdateCheck { get; set; } = null;

    public bool AppLanguageRulesEnabled { get; set; } = true;
    public List<AppLanguageRule> AppLanguageRules { get; set; } = new();

    private static readonly string Dir =
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Kright");
    private static readonly string FilePath = Path.Combine(Dir, "settings.json");

    private static AppSettings? _current;
    public static AppSettings Current => _current ??= Load();

    private static AppSettings Load()
    {
        try
        {
            if (File.Exists(FilePath))
                return JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(FilePath)) ?? new AppSettings();
        }
        catch { }
        return new AppSettings();
    }

    public static void Save()
    {
        try
        {
            Directory.CreateDirectory(Dir);
            File.WriteAllText(FilePath,
                JsonSerializer.Serialize(Current, new JsonSerializerOptions { WriteIndented = true }));
        }
        catch { }
    }
}

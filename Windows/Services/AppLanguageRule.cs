namespace Kright.Services;

public sealed class AppLanguageRule
{
    /// <summary>Full path to the executable (e.g. C:\...\notepad.exe).
    /// Used as the stable identity key for matching the active process.</summary>
    public string ExePath { get; set; } = "";

    /// <summary>Display name captured at add-time (ProductName or process name).</summary>
    public string AppName { get; set; } = "";

    /// <summary>(long) cast of the HKL handle. Standard layouts have stable HKL
    /// values across reboots; used to find the matching InputLanguage at switch time.</summary>
    public long HklValue { get; set; }

    /// <summary>Display name of the layout captured at add-time (e.g. "EN", "HE").</summary>
    public string LayoutName { get; set; } = "";
}

using System.IO;

namespace Kright.Services;

/// <summary>The two chat apps whose open conversation Kright can detect on Windows.</summary>
public enum ContactApp
{
    WhatsApp,
    Teams
}

public static class ContactAppExtensions
{
    public static string DisplayName(this ContactApp app) =>
        app == ContactApp.WhatsApp ? "WhatsApp" : "Microsoft Teams";

    /// <summary>Best-effort identification of a watched chat app from its
    /// executable path. WhatsApp ships as "WhatsApp.exe"; the new Teams as
    /// "ms-teams.exe". Match on the file name so a Store/MSIX install path still
    /// resolves.</summary>
    public static ContactApp? FromExePath(string? exePath)
    {
        if (string.IsNullOrEmpty(exePath)) return null;
        var file = Path.GetFileNameWithoutExtension(exePath).ToLowerInvariant();
        if (file.Contains("whatsapp")) return ContactApp.WhatsApp;
        if (file is "ms-teams" or "teams" || file.Contains("teams")) return ContactApp.Teams;
        return null;
    }
}

/// <summary>A rule: "when the open conversation in <see cref="App"/> is
/// <see cref="ContactName"/>, switch the keyboard to <see cref="HklValue"/>".
/// Mirrors <see cref="AppLanguageRule"/> but keyed on a contact display name.</summary>
public sealed class ContactLanguageRule
{
    public ContactApp App { get; set; }
    public string ContactName { get; set; } = "";

    /// <summary>(long) cast of the HKL handle — same identity scheme as AppLanguageRule.</summary>
    public long HklValue { get; set; }
    public string LayoutName { get; set; } = "";
}

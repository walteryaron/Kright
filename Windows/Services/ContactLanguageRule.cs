using System.IO;

namespace Kright.Services;

/// <summary>Chat apps whose open conversation Kright can detect on Windows.
/// WhatsApp is excluded — its Windows app is WebView2-based and exposes no
/// accessibility content, so contact detection is not possible.</summary>
public enum ContactApp
{
    Teams
}

public static class ContactAppExtensions
{
    public static string DisplayName(this ContactApp app) => "Microsoft Teams";

    public static ContactApp? FromExePath(string? exePath)
    {
        if (string.IsNullOrEmpty(exePath)) return null;
        var file = Path.GetFileNameWithoutExtension(exePath).ToLowerInvariant();
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

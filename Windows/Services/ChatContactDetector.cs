using System.Windows.Automation;

namespace Kright.Services;

/// <summary>Detects the currently-open conversation (contact / chat / channel
/// name) in a supported chat app, via UI Automation — the Windows analogue of
/// macOS Accessibility (see the macOS ChatContactDetector). Read-only.
///
/// Teams (WebView2/Chromium) is the only supported app: the chat name lives in
/// the window *title* ("Chat | &lt;name&gt; | Microsoft Teams") → cheap title
/// read + parse. Verified live on-device against the new Teams client
/// (ms-teams.exe).
///
/// WhatsApp is intentionally not supported on Windows. Its Windows app (both
/// the regular and Beta Store builds — confirmed identical) is a WinUI3 shell
/// around WebView2, and the entire chat UI renders inside that WebView2 with
/// nothing exposed to UI Automation: the window title never changes from
/// "WhatsApp"/"WhatsApp Beta" regardless of which chat is open, and a UIA tree
/// walk (ControlView and RawView, with a multi-second delay to let Chromium's
/// accessibility engine activate) finds zero descendants under the WebView2
/// node — confirmed live with real open chats. This isn't a WhatsApp-specific
/// bug: WebView2 hosted inside a WinUI3 app is a known, Microsoft-acknowledged
/// accessibility gap (the same WebView2 control works fine with screen readers
/// in non-WinUI3 hosts). Third-party NVDA add-ons *can* read this content, but
/// only because a real, recognized screen reader process activates Chromium's
/// accessibility tree in the first place — a plain UI Automation client (what
/// Kright is) doesn't trigger that activation, and requiring every user to run
/// a screen reader in the background just for keyboard-layout switching isn't
/// reasonable. macOS supports WhatsApp because its WhatsApp is a native
/// Catalyst app, not WebView2 — a different architecture entirely.
/// </summary>
public static class ChatContactDetector
{
    /// <param name="hwnd">Top-level window handle of the watched app (the current
    /// foreground window, supplied by the enforcer).</param>
    public static string? CurrentContact(ContactApp app, IntPtr hwnd)
    {
        if (hwnd == IntPtr.Zero) return null;
        try
        {
            var root = AutomationElement.FromHandle(hwnd);
            return root == null ? null : TeamsContact(root);
        }
        catch { return null; }
    }

    // ---- Teams (window title) ----

    private static string? TeamsContact(AutomationElement root)
    {
        var title = root.Current.Name ?? "";
        var s = title;
        int idx = s.LastIndexOf(" | Microsoft Teams", StringComparison.Ordinal);
        if (idx >= 0) s = s.Substring(0, idx);
        else if (s == "Microsoft Teams") return null;

        s = s.Trim();
        if (s.StartsWith(", ")) s = s.Substring(2);
        if (s.StartsWith("Chat | ")) s = s.Substring("Chat | ".Length);
        s = s.Trim();

        var nonChatTabs = new HashSet<string>
            { "Activity", "Chat", "Calls", "Calendar", "Teams", "Files", "Microsoft Teams", "" };
        return nonChatTabs.Contains(s) ? null : s;
    }
}

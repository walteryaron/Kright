using System.Windows.Automation;

namespace Kright.Services;

/// <summary>Detects the currently-open conversation (contact / chat / channel
/// name) in a supported chat app, via UI Automation — the Windows analogue of
/// macOS Accessibility (see the macOS ChatContactDetector). Read-only.
///
/// Two strategies, mirroring macOS:
///  • Teams (WebView2/Chromium): the chat name lives in the window *title*
///    ("Chat | &lt;name&gt; | Microsoft Teams") → cheap title read + parse. LOW RISK.
///  • WhatsApp (WinUI): best-effort tree search for the conversation header.
///    ⚠ NEEDS ON-DEVICE VERIFICATION — the anchor below is a placeholder; confirm
///    the real element with Inspect.exe / Accessibility Insights on a Windows PC
///    and adjust <see cref="WhatsAppHeaderAutomationId"/> / the search predicate.
/// </summary>
public static class ChatContactDetector
{
    /// <summary>Caps the WhatsApp UIA walk so a poll stays cheap on a large tree.</summary>
    private const int MaxNodes = 2500;

    /// ⚠ PLACEHOLDER — set this to the AutomationId of the conversation-header
    /// element once verified with Inspect.exe. Empty = fall back to the heuristic
    /// text search below.
    private const string WhatsAppHeaderAutomationId = "";

    /// <param name="hwnd">Top-level window handle of the watched app (the current
    /// foreground window, supplied by the enforcer).</param>
    public static string? CurrentContact(ContactApp app, IntPtr hwnd)
    {
        if (hwnd == IntPtr.Zero) return null;
        try
        {
            var root = AutomationElement.FromHandle(hwnd);
            if (root == null) return null;
            return app == ContactApp.Teams ? TeamsContact(root) : WhatsAppContact(root);
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

    // ---- WhatsApp (UIA tree, best-effort) ----

    private static string? WhatsAppContact(AutomationElement root)
    {
        // Preferred: a stable AutomationId, once known.
        if (WhatsAppHeaderAutomationId.Length > 0)
        {
            var byId = root.FindFirst(TreeScope.Descendants,
                new PropertyCondition(AutomationElement.AutomationIdProperty, WhatsAppHeaderAutomationId));
            var name = byId?.Current.Name?.Trim();
            if (!string.IsNullOrEmpty(name)) return Clean(name);
        }

        // Heuristic fallback: the first Header/Text element with a non-empty Name
        // that isn't obvious chrome. Bounded BFS so it stays cheap.
        // ⚠ Verify/replace this once the real tree is inspected on Windows.
        var walker = TreeWalker.ControlViewWalker;
        var queue = new Queue<AutomationElement>();
        queue.Enqueue(root);
        int budget = MaxNodes;

        while (queue.Count > 0 && budget-- > 0)
        {
            var el = queue.Dequeue();
            try
            {
                var ct = el.Current.ControlType;
                if ((ct == ControlType.Header || ct == ControlType.Text) &&
                    el.Current.Name is { Length: > 0 } n && !HeaderNoise.Contains(n))
                {
                    return Clean(n);
                }
            }
            catch { /* stale element — skip */ }

            try
            {
                var child = walker.GetFirstChild(el);
                while (child != null && budget > 0)
                {
                    queue.Enqueue(child);
                    child = walker.GetNextSibling(child);
                }
            }
            catch { }
        }
        return null;
    }

    private static readonly HashSet<string> HeaderNoise = new()
    {
        "Chats", "More", "New Chat", "Archived", "Starred", "Settings",
        "Calls", "Updates", "Search", "Clear text", "WhatsApp",
    };

    /// <summary>Strip bidi marks / whitespace so rule matching compares clean names.</summary>
    private static string Clean(string s) =>
        s.Trim('‎', '‏', '‪', '‬', ' ', '\t', '\r', '\n');
}

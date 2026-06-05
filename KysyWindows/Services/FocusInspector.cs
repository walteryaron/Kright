using System.Windows.Automation;

namespace Kysy.Services;

public record FocusedField(
    string ControlType, string Name, string HelpText, bool IsPassword, string Value)
{
    /// <summary>Best-effort field-type inference (mirrors the macOS guess).</summary>
    public string Guess
    {
        get
        {
            if (IsPassword) return "Password";
            string hay = (Name + " " + HelpText).ToLowerInvariant();
            bool Any(params string[] n) => n.Any(hay.Contains);
            if (Any("search")) return "Search";
            if (Any("phone", "tel", "mobile")) return "Phone number";
            if (Any("email", "e-mail")) return "Email";
            if (Any("url", "website", "http")) return "URL";
            if (Any("card", "cvv", "expiry")) return "Payment";
            if (Any("address", "street", "city", "zip", "postal")) return "Address";
            if (Any("name")) return "Name";
            bool textish = ControlType is "edit" or "document" or "text" or "combobox";
            return textish ? "Generic text field" : "Not a text field";
        }
    }
}

/// <summary>Reads and writes the focused UI element via UI Automation (the
/// Windows analogue of macOS Accessibility / AXUIElement).</summary>
public static class FocusInspector
{
    public static FocusedField? Focused()
    {
        try
        {
            var el = AutomationElement.FocusedElement;
            if (el is null) return null;
            var info = el.Current;
            string value = "";
            try
            {
                if (el.TryGetCurrentPattern(ValuePattern.Pattern, out var p))
                    value = ((ValuePattern)p).Current.Value ?? "";
            }
            catch { }

            return new FocusedField(
                ControlType: info.ControlType?.LocalizedControlType ?? "",
                Name: info.Name ?? "",
                HelpText: info.HelpText ?? "",
                IsPassword: info.IsPassword,
                Value: value);
        }
        catch { return null; }
    }

    /// <summary>Try to set the focused element's value via UIA ValuePattern.
    /// Returns false if the field is read-only / unsupported (e.g. console),
    /// in which case the caller should fall back to keystroke simulation.</summary>
    public static bool TrySetFocusedValue(string text)
    {
        try
        {
            var el = AutomationElement.FocusedElement;
            if (el is null) return false;
            if (!el.TryGetCurrentPattern(ValuePattern.Pattern, out var p)) return false;
            var vp = (ValuePattern)p;
            if (vp.Current.IsReadOnly) return false;
            vp.SetValue(text);
            return true;
        }
        catch { return false; }
    }
}

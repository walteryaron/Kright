using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
using Microsoft.Win32;

namespace Kysy.Services;

/// <summary>Generates the tray glyphs at runtime (no .ico assets needed): an open
/// eye for the normal "watching" state and a slashed eye for blind mode. The
/// glyph colour adapts to the taskbar theme so it stays visible on light or dark.</summary>
public static class TrayIcons
{
    public static Icon Normal { get; } = Build(blind: false);
    public static Icon Blind { get; } = Build(blind: true);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool DestroyIcon(IntPtr hIcon);

    private static Color GlyphColor()
    {
        // SystemUsesLightTheme = 1 → light taskbar → draw a dark glyph (and vice versa).
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(
                @"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
            if (key?.GetValue("SystemUsesLightTheme") is int i && i == 1)
                return Color.FromArgb(34, 34, 34);
        }
        catch { /* default to a light glyph */ }
        return Color.FromArgb(236, 236, 236);
    }

    private static Icon Build(bool blind)
    {
        const int S = 32;
        var color = GlyphColor();

        using var bmp = new Bitmap(S, S);
        using (var g = Graphics.FromImage(bmp))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.Clear(Color.Transparent);

            using var pen = new Pen(color, 2.2f) { StartCap = LineCap.Round, EndCap = LineCap.Round };
            using var brush = new SolidBrush(color);

            // Eye outline: a wide almond ellipse reads clearly as an eye at tray size.
            g.DrawEllipse(pen, 3f, 9f, S - 6f, S - 18f);
            // Iris / pupil.
            g.FillEllipse(brush, S / 2f - 4f, S / 2f - 4f, 8f, 8f);

            if (blind)
            {
                // Diagonal slash — the universal "hidden / not looking" mark. Draw a
                // transparent gap underneath first so the slash stays legible over the iris.
                using var gap = new Pen(Color.Transparent, 5f) { StartCap = LineCap.Round, EndCap = LineCap.Round };
                using var slash = new Pen(color, 2.6f) { StartCap = LineCap.Round, EndCap = LineCap.Round };
                g.CompositingMode = CompositingMode.SourceCopy;
                g.DrawLine(gap, 5f, 6f, S - 5f, S - 6f);
                g.CompositingMode = CompositingMode.SourceOver;
                g.DrawLine(slash, 5f, 6f, S - 5f, S - 6f);
            }
        }

        // GetHicon hands back an independent HICON; clone into a managed Icon we own,
        // then free the native handle so we don't leak it.
        IntPtr hicon = bmp.GetHicon();
        try
        {
            using var temp = Icon.FromHandle(hicon);
            return (Icon)temp.Clone();
        }
        finally
        {
            DestroyIcon(hicon);
        }
    }
}

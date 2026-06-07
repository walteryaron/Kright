using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
using Microsoft.Win32;

namespace Kright.Services;

/// <summary>Generates the tray glyphs at runtime (no .ico assets needed): a
/// keyboard for the normal state (matching the macOS menu-bar icon) and a slashed
/// eye for blind mode. The glyph colour adapts to the taskbar theme so it stays
/// visible on light or dark.</summary>
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
            if (blind) DrawBlindEye(g, S, color);
            else DrawKeyboard(g, S, color);
        }

        return ToIcon(bmp);
    }

    /// <summary>Keyboard glyph (mirrors the macOS "keyboard" symbol): a rounded
    /// body with two rows of keys and a spacebar.</summary>
    private static void DrawKeyboard(Graphics g, int S, Color color)
    {
        using var pen = new Pen(color, 2.0f) { LineJoin = LineJoin.Round };
        using var brush = new SolidBrush(color);

        using (var body = RoundedRect(3f, 9f, S - 6f, 15f, 3.5f))
            g.DrawPath(pen, body);

        const float ks = 2.4f;                       // key size
        float[] cols = { 7f, 11f, 15f, 19f, 23f };
        foreach (var cx in cols)
        {
            g.FillRectangle(brush, cx, 12.5f, ks, ks);   // top row
            g.FillRectangle(brush, cx, 16.4f, ks, ks);   // middle row
        }
        using (var space = RoundedRect(9f, 20.0f, S - 18f, 2.4f, 1.2f))
            g.FillPath(brush, space);                    // spacebar
    }

    /// <summary>Slashed eye for blind mode (matches macOS "eye.slash").</summary>
    private static void DrawBlindEye(Graphics g, int S, Color color)
    {
        using var pen = new Pen(color, 2.2f) { StartCap = LineCap.Round, EndCap = LineCap.Round };
        using var brush = new SolidBrush(color);

        g.DrawEllipse(pen, 3f, 9f, S - 6f, S - 18f);         // eye outline
        g.FillEllipse(brush, S / 2f - 4f, S / 2f - 4f, 8f, 8f); // iris

        // Diagonal slash; a transparent gap underneath keeps it legible over the iris.
        using var gap = new Pen(Color.Transparent, 5f) { StartCap = LineCap.Round, EndCap = LineCap.Round };
        using var slash = new Pen(color, 2.6f) { StartCap = LineCap.Round, EndCap = LineCap.Round };
        g.CompositingMode = CompositingMode.SourceCopy;
        g.DrawLine(gap, 5f, 6f, S - 5f, S - 6f);
        g.CompositingMode = CompositingMode.SourceOver;
        g.DrawLine(slash, 5f, 6f, S - 5f, S - 6f);
    }

    private static GraphicsPath RoundedRect(float x, float y, float w, float h, float r)
    {
        float d = r * 2;
        var p = new GraphicsPath();
        p.AddArc(x, y, d, d, 180, 90);
        p.AddArc(x + w - d, y, d, d, 270, 90);
        p.AddArc(x + w - d, y + h - d, d, d, 0, 90);
        p.AddArc(x, y + h - d, d, d, 90, 90);
        p.CloseFigure();
        return p;
    }

    private static Icon ToIcon(Bitmap bmp)
    {
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

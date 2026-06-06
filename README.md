# Kysy

A lightweight **native desktop keyboard utility** for **macOS and Windows** that
runs from the menu bar / system tray. Its main job: fix text you typed in the
**wrong keyboard layout** (e.g. you meant `exit` but typed `קסןא` because Hebrew
was active) — with a global hotkey, in place, in any app. It can also
**auto-switch the keyboard to English** when you focus an email / URL / password
field.

There is **no shared/cross-platform code** — each OS has its own native app:

| Platform | Stack | Folder |
|----------|-------|--------|
| macOS    | Swift + SwiftUI | [`KysyNative/`](KysyNative/) |
| Windows  | C# + WPF (.NET 8) | [`KysyWindows/`](KysyWindows/) |

## Features

- **Wrong-layout fix** — converts the focused field's last word using the
  *real* installed keyboard layouts (macOS `UCKeyTranslate` / Windows
  `ToUnicodeEx`), so it matches exactly what your keyboard types, for any
  language pair.
- **Global hotkey** — fix in place from anywhere (default `⌃⌥K` on macOS,
  `Ctrl+Alt+K` on Windows), configurable in Settings.
- **Terminal / console support** — when a field rejects accessibility writes
  (Terminal, iTerm, cmd, PowerShell), it falls back to simulated keystrokes.
- **Auto keyboard language** — optionally switch to English on email / URL /
  password fields, detected via the OS accessibility tree.
- **Live field inspector** — a Detect tab showing the focused field's type and
  attributes.

## Build & run

**macOS** (needs Xcode + [XcodeGen](https://github.com/yonaskolb/XcodeGen)):
```sh
cd KysyNative
xcodegen generate
xcodebuild -project Kysy.xcodeproj -scheme Kysy -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/Kysy.app
```
Grant **Accessibility** permission (System Settings → Privacy & Security →
Accessibility → enable Kysy).

**Windows** (needs the .NET 8 SDK — see [`KysyWindows/README.md`](KysyWindows/README.md)):
```powershell
cd KysyWindows
dotnet build
dotnet run
```

## Packaging installers

**macOS — `.dmg`** (run on a Mac with Xcode):
```sh
cd KysyNative
./scripts/build-dmg.sh        # → build/Kysy.dmg
```
The app is signed with an *Apple Development* identity but **not notarized**, so
the first launch on another Mac needs a **right-click → Open** (or
`xattr -dr com.apple.quarantine /Applications/Kysy.app`). Frictionless
distribution would require a *Developer ID* certificate + notarization.

**Windows — installer `.exe`** (run on Windows; needs the
[.NET 8 SDK](https://dotnet.microsoft.com/download) and
[Inno Setup 6](https://jrsoftware.org/isdl.php)):
```powershell
cd KysyWindows
powershell -ExecutionPolicy Bypass -File .\build-installer.ps1
# → installer\output\KysySetup-1.0.0.exe
```
This publishes a **self-contained** x64 build (the .NET runtime is bundled, so
end users install nothing extra) and wraps it in a per-user installer (no UAC),
with optional "start at login".

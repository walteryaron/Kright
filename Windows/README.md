# Kright for Windows (WPF / .NET 8)

Native Windows port of the macOS Kright app: a tray utility that fixes
wrong-keyboard-layout text and can auto-switch the keyboard to English on
email/URL/password fields — driven by a global hotkey.

## Build & run (on the Windows 11 VM)

Requires the **.NET 8 SDK** (and the Desktop workload, which Visual Studio
installs by default).

```powershell
cd Windows
dotnet build          # or open Kright.csproj in Visual Studio and press F5
dotnet run
```

The app starts in the **system tray** (look near the clock). Left-click the
icon to open the panel; right-click for **Settings / Quit**.

## Default hotkey

**Ctrl+Alt+K** — press it in any app to fix the focused field's last word.
Change it under **Settings → Fix-layout shortcut → Change…**.

## Per-app / per-contact keyboard rules

Settings lets you assign a target keyboard language to a specific app (switches
on focus) or to a specific chat (switches when that conversation is open,
overriding the app-level rule). Per-contact detection currently supports
**Microsoft Teams only** — its window title carries the open chat's name
("Chat | \<name\> | Microsoft Teams"), which `ChatContactDetector.cs` parses.

**WhatsApp is not supported for per-contact rules on Windows.** Its Windows
app (regular and Beta Store builds alike) is a WinUI3 shell around a Chromium
WebView2 that renders the entire chat UI — nothing about the open conversation
is exposed to UI Automation: the window title never changes, and a UIA tree
walk finds zero descendants under the WebView2 node, even with a real chat
open. This is a known WebView2-in-WinUI3 accessibility gap, not specific to
WhatsApp or to Kright (see the comment in `ChatContactDetector.cs` for the
full investigation). macOS supports WhatsApp because its app is native
Catalyst, not WebView2.

## How the macOS pieces map here

| Mac | Windows (this project) |
|-----|------------------------|
| `UCKeyTranslate` | `ToUnicodeEx` — `Services/KeyboardLayoutMap.cs` |
| Accessibility (AXUIElement) | UI Automation — `Services/FocusInspector.cs` |
| TIS input sources | `GetKeyboardLayoutList` — `Services/LanguageManager.cs` |
| `RegisterEventHotKey` | `RegisterHotKey` — `Services/HotkeyManager.cs` |
| AX value write | UIA `ValuePattern.SetValue` |
| Keystroke fallback (Terminal) | `SendInput` + `KEYEVENTF_UNICODE` — `Services/KeystrokeReplacer.cs` |
| Auto-language enforcer | `Services/FocusLanguageEnforcer.cs` |

## Replacement strategy (incl. consoles)

1. Try a clean **UIA ValuePattern.SetValue** (preserves cursor).
2. If the field is read-only — **cmd, PowerShell, Windows Terminal** — fall back
   to **SendInput**: N backspaces + Unicode typing. Injected events are tagged
   in `dwExtraInfo` (`KRIGHT_MARKER`) so the keyboard hook ignores Kright's own input.

## Known things to verify / iterate (I couldn't compile this on macOS)

- **UIAutomation references**: if the build says `UIAutomationClient` /
  `UIAutomationTypes` are already referenced, delete the `<ItemGroup>` with those
  `<Reference>` lines from `Kright.csproj` (the Desktop runtime may include them).
- **Tray icon**: currently uses `SystemIcons.Application` as a placeholder. Drop a
  real `app.ico` in the project and load it in `App.xaml.cs > SetupTray()`.
- **Language switch**: `LanguageManager.Switch` posts `WM_INPUTLANGCHANGEREQUEST`
  to the foreground window. Some apps honor it slowly; verify on your setup.
- **Admin windows**: an `asInvoker` app can't inspect or inject into elevated
  (Run-as-admin) windows — expected Windows security behavior.
- **Key Log tab** from the Mac app isn't ported yet (low value); the
  `WH_KEYBOARD_LL` plumbing is already in `NativeMethods.cs` if you want it.

## Project layout

```
Kright.csproj            project + framework refs
app.manifest           DPI awareness, asInvoker
App.xaml(.cs)          tray icon, hotkey wiring, FixFocusedLayout
MainWindow.xaml(.cs)   Detect + Settings tabs
Native/NativeMethods.cs  all P/Invoke
Services/
  KeyboardLayoutMap.cs   ToUnicodeEx layout reading
  LayoutConverter.cs     last-word wrong-layout detection
  GibberishDetector.cs   local English+Hebrew bigram models (is this gibberish?)
  BigramModel.cs         the bigram scorer
  LanguageModelData.cs   precomputed per-language bigram tables (regenerate via tools/gen_models_cs.swift on a Mac)
  LanguageManager.cs     enumerate / switch input languages
  FocusInspector.cs      UIA focused-field read/write + type guess
  KeystrokeReplacer.cs   SendInput fallback
  HotkeyManager.cs       global hotkey + recorder
  FocusLanguageEnforcer.cs  auto-English on Latin fields
  AppSettings.cs         JSON settings in %APPDATA%\Kright
```

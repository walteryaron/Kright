# Kysy for Windows (WPF / .NET 8)

Native Windows port of the macOS Kysy app: a tray utility that fixes
wrong-keyboard-layout text and can auto-switch the keyboard to English on
email/URL/password fields — driven by a global hotkey.

## Build & run (on the Windows 11 VM)

Requires the **.NET 8 SDK** (and the Desktop workload, which Visual Studio
installs by default).

```powershell
cd KysyWindows
dotnet build          # or open Kysy.csproj in Visual Studio and press F5
dotnet run
```

The app starts in the **system tray** (look near the clock). Left-click the
icon to open the panel; right-click for **Settings / Quit**.

## Default hotkey

**Ctrl+Alt+K** — press it in any app to fix the focused field's last word.
Change it under **Settings → Fix-layout shortcut → Change…**.

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
   in `dwExtraInfo` (`KYSY_MARKER`) so the keyboard hook ignores Kysy's own input.

## Known things to verify / iterate (I couldn't compile this on macOS)

- **UIAutomation references**: if the build says `UIAutomationClient` /
  `UIAutomationTypes` are already referenced, delete the `<ItemGroup>` with those
  `<Reference>` lines from `Kysy.csproj` (the Desktop runtime may include them).
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
Kysy.csproj            project + framework refs
app.manifest           DPI awareness, asInvoker
App.xaml(.cs)          tray icon, hotkey wiring, FixFocusedLayout
MainWindow.xaml(.cs)   Detect + Settings tabs
Native/NativeMethods.cs  all P/Invoke
Services/
  KeyboardLayoutMap.cs   ToUnicodeEx layout reading
  LayoutConverter.cs     last-word wrong-layout detection
  GibberishDetector.cs   local English+Hebrew bigram models (is this gibberish?)
  BigramModel.cs         the bigram scorer
  ModelData.cs           precomputed model tables (regenerate via tools/gen_models_cs.swift on a Mac)
  LanguageManager.cs     enumerate / switch input languages
  FocusInspector.cs      UIA focused-field read/write + type guess
  KeystrokeReplacer.cs   SendInput fallback
  HotkeyManager.cs       global hotkey + recorder
  FocusLanguageEnforcer.cs  auto-English on Latin fields
  AppSettings.cs         JSON settings in %APPDATA%\Kysy
```

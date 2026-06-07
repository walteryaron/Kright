# Kright

> **Keyboard done right.** · by [Walter Apps LTD](#made-by)

A lightweight **native desktop keyboard utility** for **macOS and Windows** that
runs from the menu bar / system tray. Its main job: fix text you typed in the
**wrong keyboard layout** (e.g. you meant `exit` but typed `קסןא` because Hebrew
was active) — with a global hotkey, in place, in any app. It can also
**auto-switch the keyboard to English** when you focus an email / URL / password
field.

There is **no shared/cross-platform code** — each OS has its own native app:

| Platform | Stack | Folder |
|----------|-------|--------|
| macOS    | Swift + SwiftUI | [`Mac/`](Mac/) |
| Windows  | C# + WPF (.NET 8) | [`Windows/`](Windows/) |

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
cd Mac
xcodegen generate
xcodebuild -project Kright.xcodeproj -scheme Kright -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/Kright.app
```
Grant **Accessibility** permission (System Settings → Privacy & Security →
Accessibility → enable Kright).

**Windows** (needs the .NET 8 SDK — see [`Windows/README.md`](Windows/README.md)):
```powershell
cd Windows
dotnet build
dotnet run
```

## Packaging installers

**macOS — `.dmg`** (run on a Mac with Xcode):
```sh
brew install create-dmg       # one-time: styled "drag to Applications" window
cd Mac
./scripts/build-dmg.sh        # → build/Kright.dmg
```
The DMG shows a custom background (`scripts/gen-dmg-bg.swift`: light panel + a
"›" chevron) with the app icon left and Applications right. `create-dmg` drives
Finder to author the window — on the **first run it prompts "Terminal wants to
control Finder"; approve it** (the layout can't be written otherwise on macOS
26+). It falls back to `dmgbuild` (headless, but its background may not render on
macOS 26) or a plain DMG if neither tool is installed.
If a **Developer ID Application** certificate and a stored notary profile
(`kysy-notary`) are present, the script automatically signs (hardened runtime),
**notarizes**, and **staples** the DMG, so it opens with a normal double-click
anywhere. The one-time setup (create the cert in Xcode; `notarytool
store-credentials`) is documented at the bottom of `scripts/build-dmg.sh`.
Without them it falls back to a dev-signed DMG whose first launch needs a
right-click → Open.

**Windows — installer `.exe`** (run on Windows; needs the
[.NET 8 SDK](https://dotnet.microsoft.com/download) and
[Inno Setup 6](https://jrsoftware.org/isdl.php)):
```powershell
cd Windows
powershell -ExecutionPolicy Bypass -File .\build-installer.ps1
# → installer\output\KrightSetup-1.0.0.exe
```
This publishes a **self-contained** x64 build (the .NET runtime is bundled, so
end users install nothing extra) and wraps it in a per-user installer (no UAC),
with optional "start at login".

## Privacy

**Kright never records, stores, sends, or sells your keystrokes. No internet. No
cloud. No AI service. No telemetry. Nothing.** Everything happens on your own
device, and only to fix the word you just typed. Password and secure fields are
never read. Because the whole app is open source, every one of these claims is
verifiable in this repo.

## Common Questions

**Does Kright record, log, or upload my keystrokes?**
No — never. It looks at only the current word, in memory, to correct the layout.
Nothing you type is written to disk, and it makes **zero** network requests.

**Does it use the internet, a cloud, or an AI service?**
No. There is no networking code anywhere in the app — no internet, no cloud, no
AI, no analytics. It works fully offline. (Detection uses a tiny on-device
statistical model, not a remote service.)

**Can it see my passwords?**
No. The moment a password or secure field is focused, Kright stops listening
entirely — you can watch this live in the Key Log ("Paused — not capturing"). On
macOS the operating system *also* blocks every app from reading secure fields.

**Does it work in any app?**
Yes — browsers, native apps, and terminals/consoles (it falls back to simulated
keystrokes where direct edits aren't allowed).

**Which languages does it support?**
The wrong-layout fix works for any installed keyboard-layout pair (it reads your
real layouts). The smart "is this gibberish?" detection currently covers
**Hebrew ⇄ English**.

**Is it open source?**
Yes — the entire app is in this repository, so you can confirm the privacy claims
yourself.

## Made by

**Walter Apps LTD** — Kright, *keyboard done right*.

## License

MIT License · Copyright © 2026 Walter Apps LTD. See [LICENSE](LICENSE).

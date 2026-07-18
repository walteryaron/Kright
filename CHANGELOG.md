# Changelog

All notable changes to **Kright** are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/), and the project follows
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Planned
- Onboarding + trust-focused Key Log on Windows (parity with macOS).

## [1.1.0] — 2026-07-18

### Added
- **Per-contact keyboard rules** — assign a target language to a specific
  chat; Kright switches the moment that conversation is open, overriding the
  per-app rule for it. macOS: WhatsApp + Teams. Windows: **Teams only** —
  WhatsApp's Windows app renders its UI inside a WebView2 control that exposes
  nothing to UI Automation (a known WebView2-in-WinUI3 accessibility gap, not
  a Kright limitation), confirmed via live on-device testing against both the
  regular and Beta Store builds.

## [1.0.8] — 2026-06-12

### Changed
- **Keyboard layouts are listed by language (macOS)** — the per-app keyboard
  dropdown and the auto-switch status line now show the language, like System
  Settings ("English", "Hebrew"), instead of raw macOS layout names ("ABC",
  "U.S.", "British"). If two enabled layouts share a language they're
  disambiguated as "English (ABC)" / "English (U.S.)". Windows is unaffected —
  its layout names already include the language.

## [1.0.7] — 2026-06-11

### Added
- **Per-app keyboard rules (macOS + Windows)** — assign a target layout to any
  app in Settings; Kright switches to it automatically when that app gains
  focus. Add the currently-focused app with one click; rules survive restarts.
- **Keyboard Map debug view** — a live "Keyboard Map" card in the debug Detect
  view shows the full key-to-character mapping for the active layout, making
  manual verification of every key easy.

### Fixed
- **Hebrew `w` key mapped to ׳ (Geresh U+05F3)** — previously mapped to ASCII
  `'`, causing wrong characters in Hebrew text.
- **Shift+symbol no longer clears the typed buffer** — typing `!` or other
  Shift-layer symbols after a word no longer wiped the buffer and broke the
  next fix. The Shift layer is now pre-computed via `UCKeyTranslate` /
  `ToUnicodeEx`.

### Added (tests)
- Punctuation round-trip unit tests for `;↔ף`, `'↔,`, `,↔ת`, `.↔ץ`, `/↔.`,
  `` `↔; ``, `w↔׳` on both macOS and Windows.

## [1.0.6] — 2026-06-09

### Fixed
- **Buffer no longer bleeds into a new tab via ⌘T (macOS)** — a new Safari tab
  reuses the single address-bar element (no focus change) and exposes no readable
  text, so the value-guard from 1.0.4 couldn't catch it. The typed buffer now
  resets on a **mouse click** (the caret/field moved) and after a **~2s typing
  pause** (a new typing context), which covers opening a new tab and typing fresh.

### Changed
- The buffer is **no longer cleared on ⌘ shortcuts** — that wiped it on ⌘⇧
  screenshots, ⌘C, ⌘Tab, etc. The click + idle resets replace it.

### Added
- **Debug Key Log** now shows a live **Buffer** row (the text the fix hotkey will
  convert) and a **Clear** button that resets the event list and the buffer.

## [1.0.4] — 2026-06-09

### Fixed
- **Stale buffer corrupting a new field/tab (macOS)** — the fix hotkey no longer
  blind-deletes when the typed buffer doesn't match the focused field. A new
  Safari tab reuses the one address-bar element, so no focus change fires and the
  previous conversion bled into the new tab. The fix now verifies the buffer is
  actually present in the field's value before writing; if it isn't, it resyncs
  to the field and beeps (press again to convert) instead of pasting stale text.
  The keystroke replacer is now reserved for genuinely read-only fields (consoles).

## [1.0.3] — 2026-06-09

### Fixed
- **Stale typed-buffer across fields/apps (macOS)** — the keystroke buffer that
  the layout-fix hotkey converts now resets when focus moves to a different field
  or app. Previously it only cleared on Enter/Tab/Esc/arrows, so switching apps
  with the mouse left the old text in the buffer — and a fix in the new app could
  delete characters and paste the previously-converted text. The always-on
  privacy watcher now also detects focus changes and clears the buffer.

## [1.0.2] — 2026-06-08

### Changed
- **Auto-update asks first** — both platforms now show a first-run "Check for
  updates automatically?" prompt instead of silently enabling background checks,
  so the user consents to the only network call Kright makes. "Check for
  Updates…" stays available manually regardless of the choice. (macOS: drop
  `SUEnableAutomaticChecks`; Windows: persisted `AutoUpdateCheck` tri-state.)

## [1.0.1] — 2026-06-08

### Added
- **Multi-language detection** — the converter now fixes any non-Latin ⇄ Latin
  layout pair, and bundled on-device bigram models cover English, Hebrew,
  Russian, Ukrainian, Bulgarian, Serbian, Macedonian, Greek, Persian, Armenian,
  and Georgian (built from Hunspell dictionaries via `tools/gen_models.swift`).
- **Auto-update (macOS)** — bundled [Sparkle](https://sparkle-project.org); a
  "Check for Updates…" menu item plus scheduled background checks against a
  signed appcast. Releases are EdDSA-signed via `Mac/scripts/gen-appcast.sh`.
- **Auto-update (Windows)** — bundled [NetSparkle](https://github.com/NetSparkleUpdater/NetSparkle);
  a "Check for Updates…" tray item plus scheduled background checks. Releases are
  Ed25519-signed via `Windows/scripts/gen-appcast.ps1` (separate feed + key from
  macOS). Set the public key in `App.xaml.cs` after `--generate-keys`.

> Windows installer shipped as `KrightSetup-1.0.1.exe`. The macOS 1.0.1 `.dmg`
> is pending a build on macOS (see appcast note below).

## [1.0.0] — 2026-06-07

First release. macOS (Swift + SwiftUI) and Windows (C# + WPF) native apps.

### Added
- **Wrong-layout fix** via a global hotkey (default `⌃⌥K` / `Ctrl+Alt+K`):
  converts the text you just typed using your *real* installed keyboard layouts,
  in place, for any language pair.
- **Multi-word and punctuation handling** — emails / URLs, and layout-dependent
  keys like `/`↔`.` and `,`↔`ת`.
- **Switches the keyboard** to the corrected language after a fix.
- **Auto-fix mode** (opt-in) — converts wrong-layout words automatically on
  Space / Tab, gated by an on-device detector.
- **Auto keyboard language** — switches to a Latin layout on email / URL /
  password fields, only when the current layout is non-Latin.
- **Blind mode** — pauses capture and shows a slashed-eye icon on password /
  secure fields; macOS Secure Input also hides them from every app.
- **On-device detection** — a tiny character-bigram model (Hebrew ⇄ English),
  trained from the system dictionaries. No network, no cloud, no AI service.
- **Terminal / console support** — falls back to simulated keystrokes (with
  clipboard save/restore) where direct edits aren't allowed.
- **Menu-bar / system-tray app** — compact Settings, Privacy + About, and a
  Debug Key Log that shows capture pausing on secure fields.
- **First-run Accessibility onboarding** (macOS) that opens the settings pane and
  auto-closes once granted.
- **Distribution** — notarized, stapled `.dmg` (macOS) and a per-user installer
  (Windows).

### Privacy
- Zero network requests. Nothing typed is stored. Password / secure fields are
  never read. The whole app is auditable in this repository.

[Unreleased]: https://github.com/walteryaron/Kright/compare/v1.0.2...HEAD
[1.0.2]: https://github.com/walteryaron/Kright/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/walteryaron/Kright/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/walteryaron/Kright/releases/tag/v1.0.0

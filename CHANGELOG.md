# Changelog

All notable changes to **Kright** are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/), and the project follows
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- **Multi-language detection** — the converter now fixes any non-Latin ⇄ Latin
  layout pair, and bundled on-device bigram models cover English, Hebrew,
  Russian, Ukrainian, Bulgarian, Serbian, Macedonian, Greek, Persian, Armenian,
  and Georgian (built from Hunspell dictionaries via `tools/gen_models.swift`).

### Planned
- Onboarding + trust-focused Key Log on Windows (parity with macOS).

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

[Unreleased]: https://github.com/walteryaron/Kright/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/walteryaron/Kright/releases/tag/v1.0.0

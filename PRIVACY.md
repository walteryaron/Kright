# Kright Privacy Policy

_Last updated: 24 July 2026_

**Kright** is a keyboard-layout utility for macOS and Windows, published by
**Walter Apps LTD**. This policy explains exactly what the app does and does not
do with your data. Because Kright is open source, every claim below is
verifiable in this repository.

## The short version

Kright does **not** collect, store, log, or transmit anything you type. It has
no accounts, no analytics, no telemetry, no ads, and no third-party SDKs. The
**only** network connection Kright ever makes is a periodic check to its own
signed update feed. Everything else happens entirely on your device.

## What Kright accesses (and why)

To fix wrong-layout text, Kright must observe the characters of the word you are
**currently** typing:

- It reads only the **current word in memory**, for the sole purpose of
  converting it to the correct keyboard layout when you ask it to (via the
  hotkey, or automatically on Space/Tab if you opt in).
- Nothing you type is ever written to disk, kept after the fix, or sent
  anywhere.
- **Password and secure fields are never read.** The moment such a field is
  focused, Kright stops observing input entirely (on Windows this is the
  "blind mode" shown by the tray icon; on macOS the operating system also blocks
  all apps from reading secure fields).

## Data we collect

**None.** Kright does not collect, receive, or process any personal information.
We have no servers that receive your data, and we have no way to identify you.

- No keystroke logs.
- No usage analytics or telemetry.
- No advertising or tracking identifiers.
- No crash reports containing personal data.
- No account, sign-in, or contact information.

## Network activity

Kright's single network connection is its **automatic update check**:

- The app periodically requests a static, signed update feed
  (an "appcast") and, if a newer version exists, downloads the signed installer.
- Updates are cryptographically verified before installation (EdDSA on macOS,
  Ed25519 on Windows).
- This request contains only what any ordinary file download involves (e.g. your
  IP address, as seen by the file host). It carries **no** personal data, and
  **nothing you type is ever included**.
- The update feed and installers are hosted on GitHub. GitHub's handling of that
  request is governed by the
  [GitHub Privacy Statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement).

If you never want this connection, you can disable automatic update checks in
the app's settings; Kright will then make no network connections at all.

## Local settings storage

Your preferences (hotkey, per-app and per-contact language rules, toggles) are
stored **locally on your device** — in `%APPDATA%\Kright` on Windows and in the
app's standard preferences location on macOS. These files never leave your
device and contain no typed content.

## Children's privacy

Kright is a general-purpose utility that collects no personal information from
anyone, including children.

## Changes to this policy

If this policy changes, we will update the date above and publish the revised
version at the same location. Material changes will be noted in the app's
release notes / changelog.

## Contact

Questions about this policy or Kright's privacy practices:

- **Email:** walter@walterapps.com
- **Security reports:** see [SECURITY.md](SECURITY.md)

_Walter Apps LTD_

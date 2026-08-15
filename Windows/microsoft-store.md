# Kright — Microsoft Store submission kit

Everything needed to submit Kright (Windows) to the Microsoft Store via the
**unpackaged EXE path** (Store Policy 10.2.9). This path keeps NetSparkle as the
single update authority — the Store just lists the same signed installer we ship
on GitHub, so there is no separate Store build and no update drift.

Publisher / account: **Walter Technologies LTD** (Company account). The Partner Center
publisher name, the Azure Trusted Signing validated organization name, and the
installer's `AppPublisher` must all read exactly `Walter Technologies LTD`.

---

## 1. Notes for certification  (paste into Partner Center "Notes for certification")

**Partner Center caps this field at 2000 characters** and silently truncates past
that — the text below is ~1930 as plain text, so keep edits inside the budget.
Copy it ready to paste (strips the `>` quoting and markdown):

```sh
awk '/^<!-- CERT-NOTES-START/{f=1;next} /^<!-- CERT-NOTES-END/{f=0} f' Windows/microsoft-store.md \
  | sed 's/^> \{0,1\}//; s/\*\*//g; s/`//g' | tee >(wc -m) | pbcopy
```

<!-- CERT-NOTES-START -->
> **What Kright is:** a keyboard-layout utility that fixes text typed in the wrong
> layout (you meant `exit` but typed `קסןא` because Hebrew was active), converting
> the current word in place via a global hotkey (default Ctrl+Alt+K).
>
> **Why it uses a low-level keyboard hook — and why it is NOT a keylogger:**
> To know the characters of the word being typed right now, it installs a
> `WH_KEYBOARD_LL` hook, used **only** to hold the current word in memory so it can
> be re-encoded to the correct layout on demand. Kright does **not** log, store, or
> transmit keystrokes:
> - Nothing typed is ever written to disk.
> - No analytics, telemetry, account, or server.
> - The only network call is the signed auto-update check (NetSparkle appcast on
>   GitHub); no typed content is ever included.
> - **Password / secure fields are never read.** A monitor detects secure fields and
>   puts the app into "blind mode" (the tray icon changes), so it visibly stops
>   observing input while a password field is focused.
>
> **Injection:** for read-only console fields (cmd, PowerShell, Windows Terminal) it
> falls back to `SendInput` to type the corrected text. Injected events are tagged
> in `dwExtraInfo` so the app ignores its own input.
>
> **Privileges:** runs `asInvoker` (no elevation). It cannot read or affect elevated
> windows — expected Windows behavior.
>
> **Open source & verifiable:** https://github.com/walteryaron/Kright
> **Privacy policy:** https://walteryaron.github.io/Kright/privacy.html
>
> **Testing:** no login required. Type a wrong-layout word in any text field and
> press Ctrl+Alt+K; the word is corrected in place.
>
> **Install verification:** per-user install via `KrightSetup-1.1.1.exe /VERYSILENT
> /SUPPRESSMSGBOXES /NORESTART` (Policy 10.2.9). Manually validated on a clean VM:
> no UI, no UAC prompt, installs to `%LOCALAPPDATA%\Programs\Kright`, and registers
> a single Add/Remove Programs entry — under HKCU rather than HKLM, since the
> install is per-user — reading Kright / Walter Technologies LTD / 1.1.1.
<!-- CERT-NOTES-END -->

> Reviewers flag keyboard-hook apps as potential keyloggers. The paragraph above is
> the mitigation — lead with it. The HKCU/HKLM sentence in "Install verification"
> is what explains the inconclusive ("?") silent-install / ARP / bundleware results
> in Partner Center's automated package validation — a per-user installer registers
> uninstall info in HKCU, which their scanner does not see. Those warnings do not
> block submission; manual validation per
> https://learn.microsoft.com/windows/apps/publish/publish-your-app/msi/manual-package-validation
> is the documented answer.

---

## 2. Store listing copy

**App name:** Kright

**Short description (≤ ~100 chars):**
> Fix wrong-keyboard-layout text in place with a hotkey — for any language pair.

**Description:**
> Kright is a lightweight, native keyboard utility that lives in your system tray.
> Its main job: fix text you typed in the wrong keyboard layout — you meant "exit"
> but got "קסןא" because Hebrew was active. Press one hotkey and Kright rewrites the
> word in place, in any app, and switches your keyboard to the right language so you
> can keep typing.
>
> It uses your real installed keyboard layouts to translate, so the result matches
> exactly what your keyboard produces — for any non-Latin ⇄ Latin language pair.
>
> FEATURES
> • Wrong-layout fix — corrects the focused field's last word with a global hotkey
>   (default Ctrl+Alt+K, configurable). No need to select the text first.
> • Works everywhere — browsers, native apps, and terminals/consoles (falls back to
>   simulated keystrokes where direct edits aren't allowed).
> • Auto-switches the keyboard after a fix, so you keep typing in the right language.
> • Auto-fix mode (opt-in) — corrects wrong-layout words automatically on Space/Tab.
> • Auto keyboard language — switch to a Latin layout on email/URL/password fields.
> • Per-app keyboard rules — assign a target language to any app; Kright switches the
>   moment that app gains focus.
> • Per-contact keyboard rules — assign a language to a specific Microsoft Teams
>   conversation; Kright switches when that chat is open.
> • Layouts shown by language ("English", "Hebrew"), like Windows Settings.
>
> PRIVATE BY DESIGN
> Nothing you type is recorded, stored, or sent anywhere. No analytics, no accounts,
> no ads. The only network connection is the app's signed auto-update check. Password
> and secure fields are never read. Kright is open source.

**What's new (per release):** pull from CHANGELOG.md.

**Search terms (max 7):**
> keyboard layout, wrong layout, fix typing, Hebrew English, layout switch,
> keyboard fixer, input language

**Category:** Productivity

**Privacy policy URL:** `https://walteryaron.github.io/Kright/privacy.html`  (see section 4)

**Age rating:** everyone (no objectionable content, no data collection).

---

## 3. Silent-install verification (Policy 10.2.9)

The Store runs the installer **silently** (no install UI; a UAC dialog would be
allowed, but Kright is per-user so there isn't one). `installer/kright.iss` is
already compatible:

- No license/info pages; `DisableProgramGroupPage=yes`.
- `PrivilegesRequired=lowest` → per-user install, no UAC.
- The `[Run]` post-install launch has `skipifsilent`, so nothing launches during a
  silent install.
- Note: the `startupicon` task defaults to **checked**, so a silent install enables
  "start at login" by default. This is acceptable and matches the interactive
  default; call it out only if a reviewer asks.

**Test before submitting** (from `installer\output`):

    KrightSetup-<version>.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART

Confirm: no windows appear, the app installs to
`%LOCALAPPDATA%\Programs\Kright`, and no app window launches. Uninstall cleanly
via Settings → Apps (Policy 10.2.7).

---

## 4. Privacy policy hosting

`PRIVACY.md` (repo root) is the source. A rendered HTML copy is at
`docs/privacy.html`. To publish it:

1. In GitHub → repo **Settings → Pages** → Source: **Deploy from a branch** →
   Branch: `main`, folder: `/docs` → Save.
2. The public URL becomes: **https://walteryaron.github.io/Kright/privacy.html**
3. Use that URL as `<PRIVACY-POLICY-URL>` in the listing and certification notes.

(Alternatively host it under walterapps.com and use that URL instead.)

---

## 5. Pre-submission checklist

- [ ] Azure Artifact Signing identity validation for Walter Technologies LTD = **Completed**.
- [ ] Certificate Profile (Public Trust) created; name in `installer/trusted-signing.json`.
- [ ] Signed release build: `.\build-installer.ps1 -Sign`; `signtool verify` passes.
- [ ] Installer + `Kright.exe` both show a valid signature chaining to a Microsoft
      Trusted Root, signed by **Walter Technologies LTD**.
- [ ] GitHub Release created; versioned installer URL is immutable.
- [ ] Privacy policy hosted; URL ready.
- [ ] Partner Center **Company** account (Walter Technologies LTD) verified.
- [x] Silent install tested (`/VERYSILENT`) — validated 2026-08-15, see §1 "Install verification".
- [ ] Submission uses "provide a link to my installer" → the versioned GitHub URL.
- [ ] Certification notes (section 1) pasted, with the privacy URL filled in.

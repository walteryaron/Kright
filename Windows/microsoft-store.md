# Kright — Microsoft Store submission kit

Everything needed to submit Kright (Windows) to the Microsoft Store via the
**unpackaged EXE path** (Store Policy 10.2.9). This path keeps NetSparkle as the
single update authority — the Store links the very same signed installer binary,
so there is no separate Store build and no update drift.

### Live listing — published 2026-08-18

Kright is live in the Store. Identifiers needed for future submissions and for
linking to the listing:

| | |
|---|---|
| **Store ID** | `XPFD0Z8630DDSF` |
| **Partner Center ID** | `e49b6405-bdcc-48f2-8bd9-863b62c07386` |
| **Web listing** | <https://apps.microsoft.com/detail/XPFD0Z8630DDSF> |
| **Store deep link** | `ms-windows-store://pdp/?productid=XPFD0Z8630DDSF` |
| **IARC Global Rating ID** | `3961cc58-f4f5-8616-8170-3f72b0bc57b1` |

The IARC ID is reusable: enter it on any other IARC-licensed storefront instead of
re-taking the questionnaire. A fresh questionnaire is only required if an update
would change an answer — for Kright that means adding in-app purchases, accounts or
user-generated content, ads, analytics, or location sharing.

Ship the next version through Partner Center's **Update app** button. Do not reopen
the published submission just to look at it — "View app" opens the wizard in *edit*
mode with live Save buttons, and saving there can spawn a draft submission.

Note that `displaycatalog.mp.microsoft.com` returns no product for this Store ID.
That is expected for unpackaged EXE/MSI listings; verify a submission went live by
fetching the `apps.microsoft.com` page instead.

### Two URLs, two jobs

The same `KrightSetup-X.Y.Z.exe` is reachable at two addresses:

| Purpose | URL | Owned by |
|---|---|---|
| **Store submission** ("provide a link to my installer") | `https://krightdownloads.blob.core.windows.net/releases/KrightSetup-X.Y.Z.exe` | Azure Blob Storage |
| **Auto-update** (NetSparkle appcast enclosure) | `https://github.com/walteryaron/Kright/releases/download/vX.Y.Z/KrightSetup-X.Y.Z.exe` | GitHub Releases |

The appcast URL comes from `$dlPrefix` in `scripts/gen-appcast.ps1`. Note what the
Ed25519 `sparkle:signature` actually covers: `netsparkle-generate-appcast` signs
the file passed to `--binaries`, while `--base-url` only writes the enclosure
address. **The signature is over the installer bytes, not the URL** — so the two
hosts could be unified onto one, provided the file served is byte-identical to the
one that was signed.

⚠️ **The blob copy of a published version can never be deleted.** The live Store
listing links the *version-pinned* blob URL, so removing that file breaks the Store
download for real users. Keep every submitted version's blob in place, not just the
newest one.

They are kept separate today for practical reasons, not cryptographic ones: the
Store submission was validated against the blob copy, and GitHub Releases is the
free, already-wired host for updates. The real rule is narrower — **never point the
appcast at a separately rebuilt binary.** A rebuild of the same version produces
different bytes, and the signature will not match. If you do consolidate,
regenerate the appcast with `gen-appcast.ps1 -Version X.Y.Z` (changing `$dlPrefix`)
rather than hand-editing the URL in `appcast-win.xml`.

Publisher / account: **Walter Technologies LTD** (Company account). The Azure Trusted
Signing validated organization name and the installer's `AppPublisher` both read
exactly `Walter Technologies LTD`.

⚠️ The **Partner Center publisher display name does not** — it went live as
`Walter Apps LTD`, which is not a registered entity. The listing therefore shows
`Walter Apps LTD` as the publisher and `Walter Technologies LTD` as the developer.
Self-service rename is currently rejected ("This company name is not available");
it needs a support ticket. Keep every *other* place reading `Walter Technologies LTD`.

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
- [ ] GitHub Release created (feeds the NetSparkle appcast); its versioned installer
      URL is immutable.
- [ ] Same signed installer uploaded to Azure Blob (`krightdownloads/releases/`);
      that versioned URL is what the Store submission points at.
- [ ] Previously published versions' blobs left in place (the live listing still
      links the version it was submitted with).
- [ ] Privacy policy hosted; URL ready.
- [ ] Partner Center **Company** account (Walter Technologies LTD) verified.
- [x] Silent install tested (`/VERYSILENT`) — validated 2026-08-15, see §1 "Install verification".
- [ ] Submission uses "provide a link to my installer" → the versioned **Azure Blob**
      URL (not the GitHub one — see "Two URLs, two jobs" at the top).
- [ ] Certification notes (section 1) pasted, with the privacy URL filled in.

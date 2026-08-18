# Kright Windows — guide for Claude (build, sign, ship, Store)

This file orients Claude Code when working in `Windows/`. It is the runbook for
building, code-signing, releasing, and submitting Kright to the Microsoft Store.
Read `Windows/microsoft-store.md` for the full Store submission kit (certification
notes, listing copy, checklist).

## What this project is
Native Windows port of Kright (WPF, .NET 8): a tray utility that fixes
wrong-keyboard-layout text via a global hotkey. No shared code with macOS. See
`README.md` for architecture and the service map.

## Distribution model (do not change without asking)
- Ships as a **self-contained, per-user Inno Setup .exe** hosted on GitHub Releases.
- Updates itself via **NetSparkle** (Ed25519-signed `appcast-win.xml` on `main`).
- Microsoft Store uses the **unpackaged EXE path** (Store Policy 10.2.9): the Store
  merely links the SAME signed installer. **Do not build an MSIX** — that would take
  updates away from NetSparkle and force a divergent build. One binary, one update
  path, listed in two places (GitHub + Store).

## Code signing (Azure Trusted / Artifact Signing)
Two independent signatures exist — keep both:
1. **Authenticode** (this section) — required by the Store and by Windows SmartScreen.
   Signs `Kright.exe` and the installer `.exe`.
2. **NetSparkle Ed25519** appcast signature — update integrity. Added by
   `scripts/gen-appcast.ps1`. NOT a substitute for Authenticode.

Signing account: Azure **Artifact Signing** account `waltertech-signing`
(resource group `kright-signing`), **Public Trust** profile, org identity
**Walter Technologies LTD**. Config lives in `installer/trusted-signing.json`.

### One-time setup on the build machine
```powershell
Install-Module -Name TrustedSigning -Scope CurrentUser -Force   # signing module
# install Azure CLI, then:
az login                                                        # auth for signing
# Windows SDK must be present (for signtool.exe)
```
The signed-in user needs the **Artifact Signing Certificate Profile Signer** role
on the signing account.

### Before the first signed build
1. Confirm Azure identity validation for Walter Technologies LTD shows **Completed**
   (Azure portal → Artifact Signing account → Identity validations).
2. Create a **Certificate Profile** (type: Public Trust) on the account.
3. Put the real values in `installer/trusted-signing.json`:
   - `Endpoint` — region endpoint (e.g. West Europe = `https://weu.codesigning.azure.net`,
     East US = `https://eus.codesigning.azure.net`). Match the account's region.
   - `CodeSigningAccountName` — the account name.
   - `CertificateProfileName` — the profile you just created (replace the placeholder).

## Build

```powershell
cd Windows
.\build-installer.ps1          # UNSIGNED test build
.\build-installer.ps1 -Sign    # signed release build (needs setup above)
```
`-Sign` signs `publish\Kright.exe` before packaging, then signs
`installer\output\KrightSetup-<version>.exe`, then runs `signtool verify /pa`.
Prereqs: .NET 8 SDK, Inno Setup 6.

## Release flow (bump → build → publish → appcast)
1. Bump `<Version>` in `Windows/Kright.csproj` AND `MyAppVersion` in
   `installer/kright.iss` to the same `X.Y.Z`.
2. `.\build-installer.ps1 -Sign`
3. `gh release create vX.Y.Z ...` and upload `KrightSetup-X.Y.Z.exe`. This is the
   copy the appcast points at.
   If the release also goes to the Store, upload the **same file** to Azure Blob —
   that copy is what Partner Center links:
   ```powershell
   az storage blob upload --account-name krightdownloads --container-name releases `
     --name KrightSetup-X.Y.Z.exe --file installer\output\KrightSetup-X.Y.Z.exe `
     --auth-mode login
   ```
4. `pwsh scripts\gen-appcast.ps1 -Version X.Y.Z` → updates `appcast-win.xml`.
5. Commit `appcast-win.xml` (+ version bumps) **via PR to `main`** — never push to
   `main` directly (see repo memory).

## Silent install (Store requirement 10.2.9)
The Store installs silently. `installer/kright.iss` is already compatible (no
license/info pages, per-user `PrivilegesRequired=lowest`, `[Run]` launch is
`skipifsilent`). Verify with:
```powershell
KrightSetup-<version>.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART
```
No windows should appear; app installs to `%LOCALAPPDATA%\Programs\Kright`.

## Microsoft Store submission

**Live since 2026-08-18** — Store ID `XPFD0Z8630DDSF`,
<https://apps.microsoft.com/detail/XPFD0Z8630DDSF>. Ship the next version through
Partner Center's **Update app** button; don't reopen the published submission to
browse it ("View app" is the wizard in edit mode). Full record, including the
reusable IARC Global Rating ID, in `microsoft-store.md`.

The steps that got it there, kept for the next submission:
1. Reserve app name **Kright**.
2. Packages → "provide a link to my installer" → the **versioned Azure Blob URL**
   (`https://krightdownloads.blob.core.windows.net/releases/KrightSetup-X.Y.Z.exe`).
   Must be versioned and immutable — never a `main`-branch or "latest" link. This is
   *not* the GitHub Release URL, which is what the NetSparkle appcast points at (see
   `microsoft-store.md`, "Two URLs, two jobs" — they can be unified if you ever want
   to, since the appcast signature covers the installer bytes, not the URL).
3. Properties/category = Productivity; privacy policy URL =
   `https://walteryaron.github.io/Kright/privacy.html`.
4. Paste **Notes for certification** from `microsoft-store.md` §1 (the keyboard-hook
   "not a keylogger" explanation — critical; reviewers flag hook apps).
5. Age rating = everyone. Submit.
6. Upload the installer to the blob container — and leave older published versions
   there, since the live listing links the version-pinned URL it was submitted with.

## Guardrails
- Publisher name must read exactly **`Walter Technologies LTD`** in the installer's
  `AppPublisher` and the Azure signing identity. Keep them identical.
- Known exception, do not "fix" it in code: the **Partner Center publisher display
  name** went live as `Walter Apps LTD` (not a registered entity). Renaming it needs
  a Microsoft support ticket, not a repo change.
- Never commit real secrets. `trusted-signing.json` holds only account/profile
  names (no keys) — auth is via `az login`, so it is safe to commit.
- All changes to `main` land via PR.

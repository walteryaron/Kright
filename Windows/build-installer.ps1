# Builds (and optionally code-signs) the Kright Windows installer.
# Run on Windows from the Windows folder:
#
#   powershell -ExecutionPolicy Bypass -File .\build-installer.ps1            # unsigned test build
#   powershell -ExecutionPolicy Bypass -File .\build-installer.ps1 -Sign      # signed release build
#
# Step 1 publishes a self-contained x64 build (the .NET 8 runtime is bundled, so
# users don't need to install anything). With -Sign, the app EXE is Authenticode-
# signed before packaging. Step 2 compiles it into a single KrightSetup-<version>.exe
# with Inno Setup, which -Sign then signs too.
#
# The Microsoft Store (policy 10.2.9) requires the installer AND every PE inside it
# to be signed with a cert chaining to a Microsoft Trusted Root CA. Azure Trusted /
# Artifact Signing (Public Trust) satisfies this, so we sign BOTH Kright.exe and the
# setup .exe. (This is separate from the NetSparkle Ed25519 appcast signature, which
# gen-appcast.ps1 adds later for update integrity.)
#
# Prereqs (install once):
#   - .NET 8 SDK        https://dotnet.microsoft.com/download
#   - Inno Setup 6      https://jrsoftware.org/isdl.php
#   For signing (-Sign) additionally:
#   - Azure CLI, then `az login`  (auth for the signing account)
#   - PowerShell module:  Install-Module -Name TrustedSigning -Scope CurrentUser -Force
#   - The signer must hold the "Artifact Signing Certificate Profile Signer" role
#     on the Azure Artifact Signing account.
#   - Fill in installer\trusted-signing.json (Endpoint / account / profile).

[CmdletBinding()]
param(
    # Authenticode-sign the app and the installer via Azure Trusted Signing.
    [switch] $Sign,
    # Path to the Trusted Signing config (Endpoint / CodeSigningAccountName / CertificateProfileName).
    [string] $SigningConfig = "$PSScriptRoot\installer\trusted-signing.json",
    # RFC-3161 timestamp server (Microsoft's, so signatures stay valid after the cert expires).
    [string] $TimestampUrl = "http://timestamp.acs.microsoft.com"
)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

# ── Signing helper ─────────────────────────────────────────────────────────────
function Invoke-Sign {
    param([Parameter(Mandatory)] [string] $File)
    if (-not (Test-Path $File)) { throw "Sign: file not found: $File" }
    Write-Host "  signing $File ..." -ForegroundColor DarkCyan
    Invoke-TrustedSigning `
        -Endpoint               $script:sign.Endpoint `
        -CodeSigningAccountName $script:sign.CodeSigningAccountName `
        -CertificateProfileName $script:sign.CertificateProfileName `
        -Files                  $File `
        -FileDigest             SHA256 `
        -TimestampRfc3161       $TimestampUrl `
        -TimestampDigest        SHA256
}

if ($Sign) {
    if (-not (Get-Command Invoke-TrustedSigning -ErrorAction SilentlyContinue)) {
        throw "TrustedSigning module not found. Run: Install-Module -Name TrustedSigning -Scope CurrentUser -Force"
    }
    if (-not (Test-Path $SigningConfig)) { throw "Signing config not found: $SigningConfig" }
    $script:sign = Get-Content $SigningConfig -Raw | ConvertFrom-Json
    if ($script:sign.CertificateProfileName -like "REPLACE_*") {
        throw "Fill in $SigningConfig with your real Endpoint / account / profile before signing."
    }
    Write-Host "Signing enabled -> $($script:sign.CodeSigningAccountName) / $($script:sign.CertificateProfileName)" -ForegroundColor Cyan
} else {
    Write-Host "Signing DISABLED (test build). Pass -Sign for a release build." -ForegroundColor Yellow
}

# ── Step 1: publish ──────────────────────────────────────────────────────────────
Write-Host "Step 1/3: dotnet publish (self-contained win-x64)..." -ForegroundColor Cyan
if (Test-Path .\publish) { Remove-Item .\publish -Recurse -Force }
dotnet publish .\Kright.csproj -c Release -r win-x64 --self-contained true `
  -p:PublishSingleFile=false -o .\publish
if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed (exit $LASTEXITCODE)" }

# Sign the app EXE before Inno packs it (so the signed binary is what ships).
if ($Sign) {
    Write-Host "Step 1b/3: signing app binary..." -ForegroundColor Cyan
    Invoke-Sign ".\publish\Kright.exe"
}

# ── Step 2: build installer ──────────────────────────────────────────────────────
Write-Host "Step 2/3: compiling installer with Inno Setup..." -ForegroundColor Cyan
# Look in the usual machine-wide spots plus the per-user location winget uses.
$isccCandidates = @(
  "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
  "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
  "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
)
$iscc = $isccCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (!$iscc) {
  throw "Inno Setup 6 not found. Install it from https://jrsoftware.org/isdl.php"
}
& $iscc .\installer\kright.iss
if ($LASTEXITCODE -ne 0) { throw "Inno Setup compile failed (exit $LASTEXITCODE)" }

# Resolve the produced installer (version comes from installer\kright.iss).
$setup = Get-ChildItem .\installer\output\KrightSetup-*.exe |
         Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $setup) { throw "No KrightSetup-*.exe found in installer\output" }

# ── Step 3: sign installer ───────────────────────────────────────────────────────
if ($Sign) {
    Write-Host "Step 3/3: signing installer..." -ForegroundColor Cyan
    Invoke-Sign $setup.FullName
    Write-Host "Verifying signature..." -ForegroundColor Cyan
    & signtool verify /pa /v $setup.FullName
    if ($LASTEXITCODE -ne 0) { throw "signtool verify failed for $($setup.Name)" }
}

Write-Host "`nDone. Installer is at: $($setup.FullName)" -ForegroundColor Green
if (-not $Sign) {
    Write-Host "NOTE: this build is UNSIGNED. Re-run with -Sign before releasing / submitting to the Store." -ForegroundColor Yellow
}

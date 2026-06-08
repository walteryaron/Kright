# Generates / updates the NetSparkle appcast for a released Kright Windows installer.
#
#   pwsh ./scripts/gen-appcast.ps1 -Version 1.1.0
#   pwsh ./scripts/gen-appcast.ps1 -Version 1.1.0 -Installer ..\installer\output\KrightSetup-1.1.0.exe
#
# Output: <repo-root>\appcast-win.xml   (commit it to `main` — that's the AppcastUrl
# baked into App.xaml.cs). The installer's download URL points at the GitHub Release.
#
# ── ONE-TIME SETUP (do this once, on your build machine) ───────────────────────
#   dotnet tool install --global NetSparkleUpdater.Tools.AppCastGenerator
#   netsparkle-generate-appcast --generate-keys     # creates + stores Ed25519 keys
#   netsparkle-generate-appcast --export            # prints the BASE64 PUBLIC KEY
#   → paste that public key into App.xaml.cs  (const Ed25519PublicKey).
#   → BACK UP the private key it stored (see --export output path). Losing it means
#     you can never sign an update existing users will accept.
#
# ── RELEASE FLOW ───────────────────────────────────────────────────────────────
#   1) Bump <Version> in Windows/Kright.csproj AND MyAppVersion in
#      installer/kright.iss to the same X.Y.Z.
#   2) dotnet publish (self-contained) → ..\publish, then ISCC installer\kright.iss
#      → installer\output\KrightSetup-X.Y.Z.exe
#   3) gh release create vX.Y.Z … && gh release upload vX.Y.Z installer\output\KrightSetup-X.Y.Z.exe
#   4) pwsh scripts\gen-appcast.ps1 -Version X.Y.Z
#   5) git add appcast-win.xml && git commit && git push    # publishes the feed
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $Version,
    [string] $Installer,
    [string] $OwnerRepo = "walteryaron/Kright"
)
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$winDir    = Split-Path -Parent $scriptDir            # Windows\
$repoRoot  = Split-Path -Parent $winDir               # repo root

if (-not $Installer) {
    $Installer = Join-Path $winDir "installer\output\KrightSetup-$Version.exe"
}
if (-not (Test-Path $Installer)) { throw "Installer not found: $Installer" }

# Each release's asset lives under its own tag path on GitHub Releases.
$tag       = "v$Version"
$dlPrefix  = "https://github.com/$OwnerRepo/releases/download/$tag/"

# Stage just the installer so the generator only picks up this one binary.
$stage = Join-Path $winDir "build\appcast"
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force -Path $stage | Out-Null
Copy-Item $Installer (Join-Path $stage (Split-Path -Leaf $Installer))

# generate-appcast writes "appcast.xml" into the output dir; we rename to appcast-win.xml.
$outDir = Join-Path $winDir "build\appcast-out"
if (Test-Path $outDir) { Remove-Item -Recurse -Force $outDir }
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

Write-Host "> Generating Windows appcast for $tag ..."
netsparkle-generate-appcast `
    --binaries $stage `
    --ext exe `
    --url $dlPrefix `
    --appcast-output-directory $outDir `
    --application-name Kright

$generated = Join-Path $outDir "appcast.xml"
if (-not (Test-Path $generated)) { throw "generate-appcast did not produce $generated" }

$dest = Join-Path $repoRoot "appcast-win.xml"
Move-Item -Force $generated $dest
Write-Host "OK  Wrote $dest"
Write-Host "    -> review it, then: git add appcast-win.xml && git commit && git push"

# Builds the Kysy Windows installer. Run on Windows from the KysyWindows folder:
#
#   powershell -ExecutionPolicy Bypass -File .\build-installer.ps1
#
# Step 1 publishes a self-contained x64 build (the .NET 8 runtime is bundled, so
# users don't need to install anything). Step 2 compiles it into a single
# KysySetup-<version>.exe with Inno Setup.
#
# Prereqs (install once):
#   - .NET 8 SDK       https://dotnet.microsoft.com/download
#   - Inno Setup 6     https://jrsoftware.org/isdl.php
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

Write-Host "Step 1/2: dotnet publish (self-contained win-x64)..." -ForegroundColor Cyan
if (Test-Path .\publish) { Remove-Item .\publish -Recurse -Force }
dotnet publish .\Kysy.csproj -c Release -r win-x64 --self-contained true `
  -p:PublishSingleFile=false -o .\publish

Write-Host "Step 2/2: compiling installer with Inno Setup..." -ForegroundColor Cyan
$iscc = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
if (!(Test-Path $iscc)) { $iscc = "${env:ProgramFiles}\Inno Setup 6\ISCC.exe" }
if (!(Test-Path $iscc)) {
  throw "Inno Setup 6 not found. Install it from https://jrsoftware.org/isdl.php"
}
& $iscc .\installer\kysy.iss

Write-Host "`nDone. Installer is at: installer\output\KysySetup-1.0.0.exe" -ForegroundColor Green

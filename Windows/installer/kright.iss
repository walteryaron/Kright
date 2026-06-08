; Inno Setup script for Kright (Windows).
; Build with: ISCC.exe installer\kright.iss  (or run ..\build-installer.ps1)
; Produces a per-user installer (no admin / UAC needed), like Chrome / VS Code.

#define MyAppName "Kright"
#define MyAppVersion "1.0.1"
#define MyAppPublisher "Yaron Walter"
#define MyAppExeName "Kright.exe"

[Setup]
; A unique, stable GUID identifies this app for upgrades/uninstall. Keep it.
AppId={{6F3C2A41-9B7E-4D2A-9C1F-A1B2C3D4E5F6}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
; Stamp the version into the setup .exe's file metadata so NetSparkle's appcast
; generator can read the version from the installer it lists.
VersionInfoVersion={#MyAppVersion}
VersionInfoProductVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\Programs\{#MyAppName}
DisableProgramGroupPage=yes
UninstallDisplayName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
; Per-user install → no UAC prompt.
PrivilegesRequired=lowest
OutputDir=output
OutputBaseFilename=KrightSetup-{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "startupicon"; Description: "Start {#MyAppName} automatically when I log in"; GroupDescription: "Startup:"

[Files]
; Everything dotnet publish produced (self-contained, so the .NET runtime is bundled).
Source: "..\publish\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{userprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{userstartup}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: startupicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent

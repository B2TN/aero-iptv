; Installeur Windows, compilé par tool\build_windows.ps1 si Inno Setup est présent.
; AppVersion et SourceDir sont transmis par le script.

#ifndef AppVersion
  #error Lancez ce script avec tool\build_windows.ps1.
#endif

[Setup]
AppId={{6F1C2A54-9B2E-4E0B-8C1D-AE10C0FEE001}
AppName=Aero IPTV
AppVersion={#AppVersion}
AppPublisher=Aero IPTV
DefaultDirName={autopf}\Aero IPTV
DefaultGroupName=Aero IPTV
DisableProgramGroupPage=yes
OutputBaseFilename=aero_iptv-{#AppVersion}-windows-x64-setup
UninstallDisplayIcon={app}\aero_iptv.exe
Compression=lzma2/max
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
WizardStyle=modern

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "german"; MessagesFile: "compiler:Languages\German.isl"
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Aero IPTV"; Filename: "{app}\aero_iptv.exe"
Name: "{autodesktop}\Aero IPTV"; Filename: "{app}\aero_iptv.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\aero_iptv.exe"; Description: "{cm:LaunchProgram,Aero IPTV}"; Flags: nowait postinstall skipifsilent

; Inno Setup Script for Amada Attendance System
; Download Inno Setup from: https://jrsoftware.org/isdl.php
; Right-click this file -> "Compile" to generate Amada_Attendance_Setup_v1.0.exe

#define MyAppName "Amada Attendance"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Amada"
#define MyAppExeName "attendance_app.exe"

[Setup]
AppId={{9B738A20-4E82-4E58-8C3E-A52834E3F451}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=Output
OutputBaseFilename=Amada_Attendance_Setup_v1.0
Compression=lzma2/max
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=lowest
DisableProgramGroupPage=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "autostart"; Description: "Run 24/7 background sync service on Windows startup (no window needed)"; GroupDescription: "ZKTeco Background Service:"

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "run_background_service.vbs"; DestDir: "{app}"; Flags: ignoreversion
Source: "install_as_service.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "stop_background_service.bat"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Start Background Sync Service"; Filename: "{app}\run_background_service.vbs"
Name: "{group}\Stop Background Sync Service"; Filename: "{app}\stop_background_service.bat"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "AmadaZkBackgroundSync"; ValueData: """{app}\{#MyAppExeName}"" --silent"; Tasks: autostart; Flags: uninsdeletevalue

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

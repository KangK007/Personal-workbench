#ifndef AppVersion
  #error AppVersion must be passed by tool/build_windows_installer.ps1.
#endif

[Setup]
AppId={{F2B0B029-083A-45C6-AB24-8F203AE46440}
AppName=个人工作台
AppVersion={#AppVersion}
AppPublisher=KangK007
AppComments=个人任务、目标与回顾工作台
DefaultDirName={localappdata}\Programs\PersonalWorkbench
UsePreviousAppDir=yes
DisableDirPage=no
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern dynamic
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\personal_workbench.exe
OutputDir=..\..\dist
OutputBaseFilename=PersonalWorkbench_{#AppVersion}_windows_setup
Compression=lzma2
SolidCompression=yes
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "zhcn"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"; InfoBeforeFile: "install-notes-zh.txt"
Name: "en"; MessagesFile: "compiler:Default.isl"; InfoBeforeFile: "install-notes-en.txt"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; Flags: unchecked
Name: "autostart"; Description: "随 Windows 启动 / Start with Windows"; Flags: unchecked

[Files]
Source: "..\..\dist\windows\app\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "emergency_recovery.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "emergency_recovery.cmd"; DestDir: "{app}"; Flags: ignoreversion

[InstallDelete]
Type: files; Name: "{userdesktop}\Personal Workbench.lnk"

[Icons]
Name: "{autoprograms}\个人工作台"; Filename: "{app}\personal_workbench.exe"
Name: "{autoprograms}\Personal Workbench"; Filename: "{app}\personal_workbench.exe"
Name: "{autoprograms}\卸载个人工作台"; Filename: "{uninstallexe}"
Name: "{userdesktop}\Personal Workbench"; Filename: "{app}\personal_workbench.exe"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: none; ValueName: "PersonalWorkbench"; Flags: deletevalue
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "PersonalWorkbench"; ValueData: """{app}\personal_workbench.exe"""; Flags: uninsdeletevalue; Tasks: autostart

[Run]
Filename: "{app}\personal_workbench.exe"; Description: "{cm:LaunchProgram,个人工作台}"; Flags: nowait postinstall skipifsilent

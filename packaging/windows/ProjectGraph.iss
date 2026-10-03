; Inno Setup 6 installer for Project Graph.
; Build the Godot export first, then run this script from packaging/windows.

#define AppName "Project Graph"
#ifndef AppVersion
#define AppVersion "0.1.21"
#endif
#define AppPublisher "Project Graph"
#define AppExeName "Project Graph.exe"
#define ExportDir "..\\..\\builds\\windows"
#ifndef BuildSuffix
#define BuildSuffix ""
#endif

[Setup]
AppId={{B1E4F1D2-1A4E-4E44-9D9A-1A5F2FBD5B1D}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\Project Graph
DefaultGroupName={#AppName}
OutputDir=..\..\builds\installer
OutputBaseFilename=ProjectGraph-Setup-{#AppVersion}{#BuildSuffix}
Compression=lzma
SolidCompression=yes
WizardStyle=modern dynamic windows11
WizardSizePercent=115
WizardImageFile=assets\wizard-light.png
WizardImageFileDynamicDark=assets\wizard-dark.png
WizardSmallImageFile=assets\brand-mark.png
WizardSmallImageFileDynamicDark=assets\brand-mark.png
DisableWelcomePage=no
ChangesAssociations=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#AppExeName}
SetupIconFile=assets\project-graph.ico

[Files]
Source: "{#ExportDir}\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#ExportDir}\Project Graph.pck"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "assets\preview.png"; DestDir: "{app}\assets"; Flags: ignoreversion skipifsourcedoesntexist

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加快捷方式："

[Registry]
; Register .prg as Project Graph documents for double-click opening.
Root: HKCU; Subkey: "Software\Classes\.prg"; ValueType: string; ValueName: ""; ValueData: "ProjectGraph.Document"; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Classes\ProjectGraph.Document"; ValueType: string; ValueName: ""; ValueData: "Project Graph 文档"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\ProjectGraph.Document\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#AppExeName},0"
Root: HKCU; Subkey: "Software\Classes\ProjectGraph.Document\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExeName}"" ""%1"""

[Run]
Filename: "{app}\{#AppExeName}"; Description: "启动 {#AppName}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}\assets"

[Code]
// Reuse Windows' native corner preference, retaining DWM shadows on Windows 11.
function DwmSetWindowAttribute(Wnd: HWND; Attribute: Integer;
  var Value: Integer; Size: Integer): Integer;
  external 'DwmSetWindowAttribute@dwmapi.dll stdcall delayload';
function GetWindowRect(Wnd: HWND; var Rect: TRect): Boolean;
  external 'GetWindowRect@user32.dll stdcall';
function CreateRoundRectRgn(Left, Top, Right, Bottom, Width, Height: Integer): THandle;
  external 'CreateRoundRectRgn@gdi32.dll stdcall';
function SetWindowRgn(Wnd: HWND; Region: THandle; Redraw: Boolean): Integer;
  external 'SetWindowRgn@user32.dll stdcall';
function DeleteObject(Obj: THandle): Boolean;
  external 'DeleteObject@gdi32.dll stdcall';

procedure RoundInstallerWindow(Wnd: HWND);
var
  Preference: Integer;
  Rect: TRect;
  Region: THandle;
begin
  Preference := 2; // DWMWCP_ROUND; DWMWA_WINDOW_CORNER_PREFERENCE = 33.
  try
    if DwmSetWindowAttribute(Wnd, 33, Preference, SizeOf(Preference)) = 0 then
      Exit;
  except
    // Older Windows versions may not expose the DWM API.
  end;
  if GetWindowRect(Wnd, Rect) then begin
    Region := CreateRoundRectRgn(0, 0, Rect.Right - Rect.Left + 1,
      Rect.Bottom - Rect.Top + 1, ScaleX(16), ScaleY(16));
    if Region <> 0 then begin
      // Windows owns a successfully assigned region; free it only on failure.
      if SetWindowRgn(Wnd, Region, True) = 0 then
        DeleteObject(Region);
    end;
  end;
end;

procedure InitializeWizard;
begin
  RoundInstallerWindow(WizardForm.Handle);
end;

procedure InitializeUninstallProgressForm;
begin
  RoundInstallerWindow(UninstallProgressForm.Handle);
end;

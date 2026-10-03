; Native Linux build with NSIS 3.11 / Modern UI 2.
Unicode true
!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "x64.nsh"
!ifndef AppVersion
  !define AppVersion "0.1.21"
!endif
!ifndef ExportDir
  !define ExportDir "../../builds/windows"
!endif
!ifndef OutputFile
  !define OutputFile "../../builds/installer/ProjectGraph-Setup-${AppVersion}-nsis.exe"
!endif
!define AppName "Project Graph"
!define AppExe "Project Graph.exe"
!define AppKey "Software\Project Graph\Installer"
!define UninstallKey "Software\Microsoft\Windows\CurrentVersion\Uninstall\ProjectGraph"
!define OldKey "Software\Microsoft\Windows\CurrentVersion\Uninstall\{B1E4F1D2-1A4E-4E44-9D9A-1A5F2FBD5B1D}_is1"
Name "${AppName} ${AppVersion}"
OutFile "${OutputFile}"
InstallDir "$LOCALAPPDATA\Programs\Project Graph"
RequestExecutionLevel user
ManifestDPIAware true
SetCompressor /SOLID lzma
ShowInstDetails show
ShowUninstDetails show
!define MUI_ICON "assets/project-graph.ico"
!define MUI_UNICON "assets/project-graph.ico"
!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\${AppExe}"
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH
!insertmacro MUI_LANGUAGE "SimpChinese"
!insertmacro MUI_LANGUAGE "English"

Function .onInit
  SetShellVarContext current
  ${IfNot} ${RunningX64}
    MessageBox MB_ICONSTOP "Project Graph requires Windows x64."
    SetErrorLevel 1
    Abort
  ${EndIf}
  ; Inno registrations can live in either registry view and either user scope.
  SetRegView 32
  ReadRegStr $0 HKCU "${OldKey}" "UninstallString"
  ReadRegStr $1 HKLM "${OldKey}" "UninstallString"
  SetRegView 64
  ReadRegStr $4 HKCU "${AppKey}" "InstallDir"
  ${If} $4 != ""
    StrCpy $INSTDIR "$4"
  ${EndIf}
  ReadRegStr $2 HKCU "${OldKey}" "UninstallString"
  ReadRegStr $3 HKLM "${OldKey}" "UninstallString"
  StrCpy $0 "$0$1$2$3"
  ${If} $0 != ""
    MessageBox MB_ICONSTOP "请先在 Windows 设置中卸载旧版 Project Graph，再运行此安装包。用户文档请保存在安装目录之外。$\r$\nUninstall the previous Inno edition in Windows Settings before installing this edition."
    SetErrorLevel 1
    Abort
  ${EndIf}
FunctionEnd

Function .onVerifyInstDir
  ReadRegStr $0 HKCU "${AppKey}" "InstallDir"
  ${If} $0 != ""
  ${AndIf} $0 != $INSTDIR
    ; Upgrade in place; changing paths requires uninstalling first.
    Abort
  ${EndIf}
FunctionEnd

Section "Project Graph（必需）" Main
  SectionIn RO
  SetOutPath "$INSTDIR"
  ClearErrors
  File "${ExportDir}/Project Graph.exe"
  !if /FileExists "${ExportDir}/Project Graph.pck"
    File "${ExportDir}/Project Graph.pck"
  !endif
  ${If} ${Errors}
    MessageBox MB_ICONSTOP "无法写入程序文件。请关闭 Project Graph 并检查安装目录权限。"
    SetErrorLevel 1
    Abort
  ${EndIf}
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  ${If} ${Errors}
    SetErrorLevel 1
    Abort
  ${EndIf}
  WriteRegStr HKCU "${AppKey}" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "${UninstallKey}" "DisplayName" "${AppName}"
  WriteRegStr HKCU "${UninstallKey}" "DisplayVersion" "${AppVersion}"
  WriteRegStr HKCU "${UninstallKey}" "Publisher" "Project Graph"
  WriteRegStr HKCU "${UninstallKey}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UninstallKey}" "DisplayIcon" "$INSTDIR\${AppExe},0"
  WriteRegStr HKCU "${UninstallKey}" "UninstallString" '$\"$INSTDIR\Uninstall.exe$\"'
  WriteRegStr HKCU "${UninstallKey}" "QuietUninstallString" '$\"$INSTDIR\Uninstall.exe$\" /S'
  WriteRegDWORD HKCU "${UninstallKey}" "NoModify" 1
  WriteRegDWORD HKCU "${UninstallKey}" "NoRepair" 1
  CreateShortcut "$SMPROGRAMS\Project Graph.lnk" "$INSTDIR\${AppExe}"
SectionEnd

Section /o "桌面快捷方式" Desktop
  CreateShortcut "$DESKTOP\Project Graph.lnk" "$INSTDIR\${AppExe}"
SectionEnd

Section "关联 .prg 文档" Association
  ; Preserve the previous association once, including across upgrades.
  ReadRegDWORD $0 HKCU "${AppKey}" "AssociationSaved"
  ${If} $0 != 1
    ReadRegStr $1 HKCU "Software\Classes\.prg" ""
    WriteRegStr HKCU "${AppKey}" "PreviousAssociation" "$1"
    WriteRegDWORD HKCU "${AppKey}" "AssociationSaved" 1
  ${EndIf}
  WriteRegStr HKCU "Software\Classes\.prg" "" "ProjectGraph.Document"
  WriteRegStr HKCU "Software\Classes\ProjectGraph.Document" "" "Project Graph 文档"
  WriteRegStr HKCU "Software\Classes\ProjectGraph.Document\DefaultIcon" "" '$\"$INSTDIR\${AppExe}$\",0'
  WriteRegStr HKCU "Software\Classes\ProjectGraph.Document\shell\open\command" "" '$\"$INSTDIR\${AppExe}$\" $\"%1$\"'
  System::Call 'shell32::SHChangeNotify(i 0x08000000, i 0, p 0, p 0)'
SectionEnd

Function un.onInit
  SetShellVarContext current
  SetRegView 64
FunctionEnd

Section "Uninstall"
  ; Never recursively remove the application directory or user documents.
  ClearErrors
  Delete "$INSTDIR\${AppExe}"
  Delete "$INSTDIR\Project Graph.pck"
  ${If} ${Errors}
    MessageBox MB_ICONSTOP "请关闭 Project Graph 后重新卸载。"
    SetErrorLevel 1
    Abort
  ${EndIf}
  Delete "$SMPROGRAMS\Project Graph.lnk"
  Delete "$DESKTOP\Project Graph.lnk"
  ReadRegStr $0 HKCU "Software\Classes\.prg" ""
  ${If} $0 == "ProjectGraph.Document"
    ReadRegStr $1 HKCU "${AppKey}" "PreviousAssociation"
    ${If} $1 == ""
      DeleteRegValue HKCU "Software\Classes\.prg" ""
      DeleteRegKey /ifempty HKCU "Software\Classes\.prg"
    ${Else}
      WriteRegStr HKCU "Software\Classes\.prg" "" "$1"
    ${EndIf}
  ${EndIf}
  ReadRegStr $0 HKCU "Software\Classes\ProjectGraph.Document\shell\open\command" ""
  ${If} $0 == '$\"$INSTDIR\${AppExe}$\" $\"%1$\"'
    DeleteRegKey HKCU "Software\Classes\ProjectGraph.Document"
  ${EndIf}
  System::Call 'shell32::SHChangeNotify(i 0x08000000, i 0, p 0, p 0)'
  DeleteRegKey HKCU "${UninstallKey}"
  DeleteRegKey HKCU "${AppKey}"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
SectionEnd

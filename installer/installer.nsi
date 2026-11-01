; Installer for the Survey Toolkit (Flutter Windows build, no WebView2).
; Per user, no administrator rights: installs to %LOCALAPPDATA%\Survey Toolkit\Program, adds Start
; menu and desktop shortcuts and an entry in Settings -> Apps. Silent with /S (the self-updater uses
; /S /UPDATE and the Toolkit is opened again afterwards).
; The tools the Toolkit installs (from T3) keep their own installers and uninstallers; uninstalling
; the Toolkit removes only its Program folder and leaves the tools where they are.
Unicode true
!ifndef VERSION
  !define VERSION "0.0.0"
!endif
!ifndef SOURCE
  !define SOURCE "..\build\windows\x64\runner\Release"
!endif
!define APP "Survey Toolkit"
!define EXE "SurveyToolkit.exe"
!define KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\SurveyToolkit"

Name "${APP}"
OutFile "SurveyToolkit-Setup.exe"
InstallDir "$LOCALAPPDATA\Survey Toolkit\Program"
InstallDirRegKey HKCU "Software\SurveyToolkit" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma
ShowInstDetails show

!include "MUI2.nsh"
!include "FileFunc.nsh"
!define MUI_ICON "icon.ico"
!define MUI_UNICON "icon.ico"
!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\${EXE}"
!define MUI_FINISHPAGE_RUN_TEXT "Open ${APP} now"

!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

VIProductVersion "${VERSION}.0"
VIAddVersionKey "ProductName" "${APP}"
VIAddVersionKey "CompanyName" "Excel to KML"
VIAddVersionKey "FileDescription" "${APP} installer"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "ProductVersion" "${VERSION}"
VIAddVersionKey "LegalCopyright" "Copyright (c) 2026 Asjad Mehmood"

Section "Install"
  ; Windows will not overwrite a running program, so close it first
  nsExec::Exec 'taskkill /F /IM "${EXE}"'
  Sleep 800

  SetOutPath "$INSTDIR"
  ; the old files go first, so nothing from an earlier version is left behind
  RMDir /r "$INSTDIR\data"
  File /r "${SOURCE}\*.*"
  File "icon.ico"

  WriteRegStr HKCU "Software\SurveyToolkit" "InstallDir" "$INSTDIR"
  WriteUninstaller "$INSTDIR\Uninstall.exe"

  CreateDirectory "$SMPROGRAMS\${APP}"
  CreateShortcut "$SMPROGRAMS\${APP}\${APP}.lnk" "$INSTDIR\${EXE}" "" "$INSTDIR\icon.ico"
  CreateShortcut "$DESKTOP\${APP}.lnk" "$INSTDIR\${EXE}" "" "$INSTDIR\icon.ico"

  WriteRegStr HKCU "${KEY}" "DisplayName" "${APP}"
  WriteRegStr HKCU "${KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "${KEY}" "Publisher" "Excel to KML"
  WriteRegStr HKCU "${KEY}" "URLInfoAbout" "https://www.exceltokml.com"
  WriteRegStr HKCU "${KEY}" "DisplayIcon" "$INSTDIR\icon.ico"
  WriteRegStr HKCU "${KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKCU "${KEY}" "QuietUninstallString" '"$INSTDIR\Uninstall.exe" /S'
  WriteRegDWORD HKCU "${KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${KEY}" "NoRepair" 1
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  IntFmt $0 "0x%08X" $0
  WriteRegDWORD HKCU "${KEY}" "EstimatedSize" "$0"

  ; started by the self-updater: open the new version again
  ${GetParameters} $R0
  ${GetOptions} $R0 "/UPDATE" $R1
  IfErrors +2 0
    Exec '"$INSTDIR\${EXE}"'
SectionEnd

Section "Uninstall"
  nsExec::Exec 'taskkill /F /IM "${EXE}"'
  Sleep 500
  Delete "$DESKTOP\${APP}.lnk"
  RMDir /r "$SMPROGRAMS\${APP}"
  RMDir /r "$INSTDIR"
  ; the Survey Toolkit folder goes too, but only when nothing else is left in it
  RMDir "$LOCALAPPDATA\Survey Toolkit"
  DeleteRegKey HKCU "${KEY}"
  DeleteRegKey HKCU "Software\SurveyToolkit"
SectionEnd

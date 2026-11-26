!include "MUI2.nsh"
; The name of the installer
Name "Chameleon Ultra GUI Plus"

; The file to write
OutFile "ChameleonUltraGUIPlus-setup-win.exe"

; Request application privileges for Windows Vista and higher
RequestExecutionLevel admin

; Build Unicode installer
Unicode True

; The default installation directory
InstallDir $PROGRAMFILES\ChameleonUltraGUIPlus

; Registry key to check for directory (so if you install again, it will 
; overwrite the old one automatically)
InstallDirRegKey HKLM "Software\ChameleonUltraGUIPlus" "Install_Dir"
!define MUI_ICON "chameleonultragui\windows\runner\resources\app_icon.ico"

;--------------------------------

; Pages
!insertmacro MUI_PAGE_LICENSE "LICENSE"
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
  
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

;--------------------------------

!insertmacro MUI_LANGUAGE "English"


; The stuff to install
Section "Chameleon Ultra GUI Plus (required)"

  SectionIn RO
  
  ; Set output path to the installation directory.
  SetOutPath $INSTDIR
  
  ; Put file there
  File /r "chameleonultragui\build\windows\x64\runner\Release\*.*"
  File "LICENSE"
  
  ; Write the installation path into the registry
  WriteRegStr HKLM SOFTWARE\ChameleonUltraGUIPlus "Install_Dir" "$INSTDIR"
  
  ; Write the uninstall keys for Windows
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ChameleonUltraGUIPlus" "DisplayName" "Chameleon Ultra GUI Plus"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ChameleonUltraGUIPlus" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ChameleonUltraGUIPlus" "NoModify" 1
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ChameleonUltraGUIPlus" "NoRepair" 1
  WriteUninstaller "$INSTDIR\uninstall.exe"
  
SectionEnd

; Optional section (can be disabled by the user)
Section "Start Menu Shortcuts"
  CreateShortcut "$SMPROGRAMS\Chameleon Ultra GUI Plus.lnk" "$INSTDIR\ChameleonUltraGUIPlus.exe"
SectionEnd

; Optional section (can be disabled by the user)
Section "Desktop Shortcut"
  CreateShortcut "$DESKTOP\Chameleon Ultra GUI Plus.lnk" "$INSTDIR\ChameleonUltraGUIPlus.exe"
SectionEnd

;--------------------------------

; Uninstaller

Section "Uninstall"
  
  ; Remove registry keys
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\ChameleonUltraGUIPlus"
  DeleteRegKey HKLM SOFTWARE\ChameleonUltraGUIPlus

  ; Remove shortcuts, if any
  Delete "$SMPROGRAMS\Chameleon Ultra GUI Plus.lnk"
  Delete "$DESKTOP\Chameleon Ultra GUI Plus.lnk"

  ; Remove installation directory and all contents
  RMDir /r "$INSTDIR"

SectionEnd

; Installatore di Catorweb Broadcaster (Inno Setup 6). Si crea con build_exe.ps1.
; Installa per l'utente corrente (niente permessi di amministratore):
; %LOCALAPPDATA%\Programs\Catorweb Broadcaster (chi aggiorna resta nella cartella di prima). I dati stanno in
; %APPDATA%\CatorwebPC e NON vengono cancellati disinstallando.

#define AppName "Catorweb Broadcaster"
#define AppVersion "2.12"

[Setup]
AppId={{6F1C2B7E-5D2A-4C1B-9E33-CA70DE0B1C01}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Catorweb
DefaultDirName={localappdata}\Programs\Catorweb Broadcaster
DefaultGroupName={#AppName}
; nome cambiato (era Catorweb PC): il gruppo nuovo sostituisce il vecchio
UsePreviousGroup=no
PrivilegesRequired=lowest
OutputDir=build
OutputBaseFilename=Setup_CatorwebBroadcaster
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\CatorwebBroadcaster.exe
SetupIconFile=app\icon.ico
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
; la lingua dell'installatore segue quella di Windows (si puo' scegliere all'inizio)
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"

[CustomMessages]
english.DesktopIcon=Create a Desktop icon
english.Icons=Icons:
english.ReadMe=Read me
english.Uninstall=Uninstall
english.Launch=Start
italian.DesktopIcon=Crea un'icona sul Desktop
italian.Icons=Icone:
italian.ReadMe=Leggimi
italian.Uninstall=Disinstalla
italian.Launch=Avvia

[Tasks]
Name: "desktopicon"; Description: "{cm:DesktopIcon}"; GroupDescription: "{cm:Icons}"

[Files]
Source: "build\pacchetto\CatorwebBroadcaster\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[InstallDelete]
; aggiornando dalla versione col vecchio nome (Catorweb PC): via icone e programma vecchi
Type: files; Name: "{autodesktop}\Catorweb PC.lnk"
Type: filesandordirs; Name: "{autoprograms}\Catorweb PC"
Type: files; Name: "{app}\CatorwebPC.exe"

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\CatorwebBroadcaster.exe"
Name: "{group}\{cm:ReadMe}"; Filename: "{app}\LEGGIMI.txt"; Languages: italian
Name: "{group}\{cm:ReadMe}"; Filename: "{app}\README.txt"; Languages: english
Name: "{group}\{cm:Uninstall} {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\CatorwebBroadcaster.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\CatorwebBroadcaster.exe"; Description: "{cm:Launch} {#AppName}"; Flags: nowait postinstall skipifsilent
















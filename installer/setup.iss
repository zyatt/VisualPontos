#define MyAppName "Controle de Pontos para Premiação"
#define MyAppVersion "1.6.0"
#define MyAppPublisher "Matheus Vinícius" 
#define MyAppExeName "visualpremiumpontos.exe"
#define MyAppId "{{9F3D1A67-5E8B-4C2A-BF7D-1A6E9C4B7890}"


[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
UninstallDisplayName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
SetupIconFile=logo.ico
OutputDir=.
OutputBaseFilename=ControlePontosSetup-{#MyAppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin

; --- Atualização inteligente ---
CloseApplications=force
RestartApplications=yes
DisableDirPage=auto
DisableProgramGroupPage=auto

VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} Setup
VersionInfoCopyright=Copyright © 2024-2026 {#MyAppPublisher}

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "Criar atalho na Área de Trabalho"; GroupDescription: "Atalhos:"; Flags: checkablealone

[Files]
Source: "..\frontend\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion
Source: "config.json"; DestDir: "{commonappdata}\ControlePontosPremiacao"; Flags: onlyifdoesntexist uninsneveruninstall

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
Root: HKLM; Subkey: "Software\{#MyAppPublisher}\{#MyAppName}"; \
ValueType: string; ValueName: "Version"; ValueData: "{#MyAppVersion}"; \
Flags: uninsdeletekey

[Run]
; Para atualização silenciosa (Flutter) — abre automaticamente
Filename: "{app}\{#MyAppExeName}"; \
Flags: nowait; \
Check: ShouldRunApp

; Para instalação manual — mostra checkbox pro usuário
Filename: "{app}\{#MyAppExeName}"; \
Description: "Abrir {#MyAppName}"; \
Flags: nowait postinstall skipifsilent

[Code]
var
  IsUpgradeInstall: Boolean;

function IsUpgrade(): Boolean;
var
  OldVersion: String;
begin
  Result := RegQueryStringValue(
    HKLM,
    'Software\{#MyAppPublisher}\{#MyAppName}',
    'Version',
    OldVersion
  );
end;

function InitializeSetup(): Boolean;
begin
  IsUpgradeInstall := IsUpgrade();

  if IsUpgradeInstall then
    Log('Modo: ATUALIZAÇÃO')
  else
    Log('Modo: INSTALAÇÃO NOVA');

  Result := True;
end;

function ShouldRunApp(): Boolean;
begin
  if WizardSilent and IsUpgradeInstall then
  begin
    Log('Abrindo app após atualização silenciosa...');
    Result := True;
    Exit;
  end;

  Result := False;
end;

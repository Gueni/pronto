# Builds build\Chakchouka_Setup.exe:
#   1. exports the game with Godot (preset "Chakchouka" in export_presets.cfg) to build\Chakchouka.exe
#   2. packs it with install.ps1 / uninstall.ps1 into a self-extracting installer with
#      IExpress, which ships with Windows.
#
#   powershell -ExecutionPolicy Bypass -File installer\build_installer.ps1 [-Godot <path to godot console exe>] [-SkipExport]
#
# Needs the Godot 4.7.2 Windows export template in %APPDATA%\Godot\export_templates\4.7.2.stable
# (Editor > Manage Export Templates installs it).
param(
	[string]$Godot = "C:\Program Files\Godot\Godot_v4.7.2-stable_win64_console.exe",
	[switch]$SkipExport
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$build = Join-Path $root "build"
$stage = Join-Path $build "stage"
New-Item -ItemType Directory -Force -Path $build | Out-Null

if (-not $SkipExport) {
	Write-Host "Exporting the game..."
	& $Godot --headless --path $root --export-release "Chakchouka" (Join-Path $build "Chakchouka.exe")
	if ($LASTEXITCODE -ne 0) { throw "Godot export failed ($LASTEXITCODE)" }
}
$game = Join-Path $build "Chakchouka.exe"
if (-not (Test-Path $game)) { throw "No $game - export the game first" }

Remove-Item -Recurse -Force $stage -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $stage | Out-Null
Copy-Item $game, (Join-Path $root "installer\install.ps1"), (Join-Path $root "installer\uninstall.ps1") $stage

$target = Join-Path $build "Chakchouka_Setup.exe"
$sed = Join-Path $build "chakchouka.sed"
@"
[Version]
Class=IEXPRESS
SEDVersion=3
[Options]
PackagePurpose=InstallApp
ShowInstallProgramWindow=1
HideExtractAnimation=0
UseLongFileName=1
InsideCompressed=0
CAB_FixedSize=0
CAB_ResvCodeSigning=0
RebootMode=N
InstallPrompt=%InstallPrompt%
DisplayLicense=%DisplayLicense%
FinishMessage=%FinishMessage%
TargetName=%TargetName%
FriendlyName=%FriendlyName%
AppLaunched=%AppLaunched%
PostInstallCmd=%PostInstallCmd%
AdminQuietInstCmd=%AdminQuietInstCmd%
UserQuietInstCmd=%UserQuietInstCmd%
SourceFiles=SourceFiles
[Strings]
InstallPrompt=Install CHAKCHOUKA, the spicy roguelike, on this computer?
DisplayLicense=
FinishMessage=
TargetName=$target
FriendlyName=Chakchouka Setup
AppLaunched=powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File install.ps1
PostInstallCmd=<None>
AdminQuietInstCmd=powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File install.ps1 -Quiet
UserQuietInstCmd=powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File install.ps1 -Quiet
FILE0="Chakchouka.exe"
FILE1="install.ps1"
FILE2="uninstall.ps1"
[SourceFiles]
SourceFiles0=$stage\
[SourceFiles0]
%FILE0%=
%FILE1%=
%FILE2%=
"@ | Set-Content -Path $sed -Encoding ASCII

Remove-Item $target -ErrorAction SilentlyContinue
Write-Host "Packing the installer (this takes a minute)..."
# (IExpress fails on a quoted path to the .sed: the project folder must not contain spaces)
if ($sed.Contains(" ")) { throw "IExpress cannot handle spaces in $sed - move the project to a path without spaces" }
$p = Start-Process -FilePath (Join-Path $env:WINDIR "System32\iexpress.exe") -ArgumentList "/N", "/Q", $sed -Wait -PassThru
if (-not (Test-Path $target)) { throw "IExpress did not produce $target (exit $($p.ExitCode))" }
Remove-Item -Recurse -Force $stage
Write-Host ("Done: {0} ({1:N0} MB)" -f $target, ((Get-Item $target).Length / 1MB))

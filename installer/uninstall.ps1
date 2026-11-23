# CHAKCHOUKA uninstaller: removes the game, its shortcuts and its entry in Installed apps.
# Saves and settings (%APPDATA%\Godot\app_userdata\Chakchouka) are kept.
param([switch]$Quiet)
$ErrorActionPreference = "SilentlyContinue"
$shell = New-Object -ComObject WScript.Shell
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not $Quiet) {
	if ($shell.Popup("Remove CHAKCHOUKA from this computer?`n`n(Your saves and settings are kept.)", 0, "Chakchouka", 36) -ne 6) { exit 1 }
}
Get-Process -Name "Chakchouka" | Where-Object { $_.Path -and $_.Path.StartsWith($dir, [StringComparison]::OrdinalIgnoreCase) } | Stop-Process -Force
Start-Sleep -Milliseconds 500
foreach ($place in @([Environment]::GetFolderPath("Programs"), [Environment]::GetFolderPath("Desktop"))) {
	Remove-Item -LiteralPath (Join-Path $place "Chakchouka.lnk") -Force
}
Remove-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Chakchouka" -Recurse -Force
Remove-Item -LiteralPath (Join-Path $dir "Chakchouka.exe") -Force
# this script is still running from that folder: let a short-lived cmd delete the rest
Start-Process -FilePath "cmd.exe" -ArgumentList "/c timeout /t 2 /nobreak >nul & rmdir /s /q `"$dir`"" -WindowStyle Hidden
if (-not $Quiet) { $shell.Popup("CHAKCHOUKA has been removed. Bslema!", 0, "Chakchouka", 64) | Out-Null }

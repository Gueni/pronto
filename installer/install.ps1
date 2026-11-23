# CHAKCHOUKA installer. Run by Chakchouka_Setup.exe from the folder it unpacked itself into.
# Installs for the current user only (no admin rights needed):
#   %LOCALAPPDATA%\Programs\Chakchouka   the game and its uninstaller
#   Start menu + desktop shortcuts
#   an entry in Settings > Apps > Installed apps, to uninstall it
# Saves and settings live in %APPDATA%\Godot\app_userdata\Chakchouka and are never touched.
param(
	[string]$Target = (Join-Path $env:LOCALAPPDATA "Programs\Chakchouka"),
	[switch]$NoShortcuts,   # for testing: no shortcuts, no registry entry
	[switch]$Quiet          # no questions, no launch at the end
)
$ErrorActionPreference = "Stop"
$src = Split-Path -Parent $MyInvocation.MyCommand.Path
$shell = New-Object -ComObject WScript.Shell
$version = "1.0.0"

function Say($text, $buttons = 64) {
	if ($Quiet) { return 6 }
	return $shell.Popup($text, 0, "Chakchouka Setup", $buttons)
}

try {
	# the game must not be running while its file is replaced
	$running = Get-Process -Name "Chakchouka" -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($Target, [StringComparison]::OrdinalIgnoreCase) }
	if ($running) {
		if ((Say "CHAKCHOUKA is running. Close it and continue?" 33) -ne 1) { exit 1 }
		$running | ForEach-Object { $_.CloseMainWindow() | Out-Null }
		Start-Sleep -Seconds 2
		$running | Where-Object { -not $_.HasExited } | Stop-Process -Force
	}

	New-Item -ItemType Directory -Force -Path $Target | Out-Null
	Copy-Item -Path (Join-Path $src "Chakchouka.exe") -Destination $Target -Force
	Copy-Item -Path (Join-Path $src "uninstall.ps1") -Destination $Target -Force
	$exe = Join-Path $Target "Chakchouka.exe"

	if (-not $NoShortcuts) {
		$places = @([Environment]::GetFolderPath("Programs"), [Environment]::GetFolderPath("Desktop"))
		foreach ($dir in $places) {
			$lnk = $shell.CreateShortcut((Join-Path $dir "Chakchouka.lnk"))
			$lnk.TargetPath = $exe
			$lnk.WorkingDirectory = $Target
			$lnk.IconLocation = "$exe,0"
			$lnk.Description = "Chakchouka - a spicy roguelike for 1 to 4 friends"
			$lnk.Save()
		}
		$key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Chakchouka"
		New-Item -Path $key -Force | Out-Null
		$uninstall = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $Target 'uninstall.ps1')`""
		$values = @{
			"DisplayName" = "Chakchouka"; "DisplayVersion" = $version; "Publisher" = "Chakchouka";
			"DisplayIcon" = "$exe,0"; "InstallLocation" = $Target; "UninstallString" = $uninstall;
			"QuietUninstallString" = "$uninstall -Quiet"
		}
		foreach ($k in $values.Keys) { Set-ItemProperty -Path $key -Name $k -Value $values[$k] }
		Set-ItemProperty -Path $key -Name "NoModify" -Value 1 -Type DWord
		Set-ItemProperty -Path $key -Name "NoRepair" -Value 1 -Type DWord
		Set-ItemProperty -Path $key -Name "EstimatedSize" -Value ([int]((Get-Item $exe).Length / 1KB)) -Type DWord
	}

	if ((Say "CHAKCHOUKA is installed!`n`nYou will find it in the Start menu and on your desktop.`n`nPlay now?" 36) -eq 6 -and -not $Quiet) {
		Start-Process -FilePath $exe -WorkingDirectory $Target
	}
	exit 0
}
catch {
	Say ("The installation failed:`n`n" + $_.Exception.Message) 16 | Out-Null
	exit 1
}

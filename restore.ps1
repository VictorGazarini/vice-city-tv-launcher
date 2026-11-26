<#
.SYNOPSIS
  Volta para a tela inicial original da TV. Com -Uninstall, remove tambem o Vice City Home.
.EXAMPLE
  .\restore.ps1 -TvIp 192.168.1.50
#>
param(
    [Parameter(Mandatory = $true)][string]$TvIp,
    [switch]$Uninstall
)

# 'Continue': no PowerShell 5.1, avisos do adb no stderr nao podem abortar o script; os erros sao conferidos um a um.
$ErrorActionPreference = 'Continue'
$adb = (Get-Command adb -ErrorAction SilentlyContinue).Source
if (-not $adb) { Write-Host 'ADB nao encontrado: winget install Google.PlatformTools' -ForegroundColor Red; exit 1 }
$serial = if ($TvIp -match ':\d+$') { $TvIp } else { "${TvIp}:5555" }
& $adb connect $serial | Out-Host
Start-Sleep -Seconds 2
if ((& $adb -s $serial get-state 2>$null) -ne 'device') { Write-Host 'A TV nao respondeu pelo ADB.' -ForegroundColor Red; exit 1 }

$installed = (& $adb -s $serial shell pm list packages) -join "`n"
$stock = @('com.google.android.apps.tv.launcherx', 'com.google.android.tvlauncher') |
    Where-Object { $installed -match "(?m)^package:$([regex]::Escape($_))\s*$" } | Select-Object -First 1
if (-not $stock) { Write-Host 'Tela inicial original nao encontrada. Nada foi alterado.' -ForegroundColor Red; exit 1 }

& $adb -s $serial shell pm enable --user 0 $stock | Out-Host
if ($installed -match 'com\.google\.android\.tungsten\.setupwraith') {
    & $adb -s $serial shell pm enable --user 0 com.google.android.tungsten.setupwraith | Out-Host
}
$component = (& $adb -s $serial shell "cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.HOME | grep '$stock/' | head -1") -join ''
if ($component.Trim()) { & $adb -s $serial shell cmd package set-home-activity --user 0 $component.Trim() | Out-Host }
& $adb -s $serial shell input keyevent KEYCODE_HOME
Start-Sleep -Seconds 4

$now = ((& $adb -s $serial shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME) | Select-Object -Last 1)
if ($now -notlike "$stock/*") {
    Write-Host "A tela original ainda nao e o Home (atual: $now). O Vice City Home foi mantido instalado." -ForegroundColor Yellow
    exit 1
}
Write-Host 'Tela inicial original restaurada.' -ForegroundColor Green
if ($Uninstall) { & $adb -s $serial uninstall com.vicecity.home | Out-Host }

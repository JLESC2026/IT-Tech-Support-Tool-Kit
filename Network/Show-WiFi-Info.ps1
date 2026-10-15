$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'Show Wi-Fi information'
Write-Header $A

$svc = Get-Service -Name WlanSvc -ErrorAction SilentlyContinue
if (-not $svc) {
    Write-Warn 'This PC has no Wi-Fi adapter (WLAN AutoConfig service is not installed).'
    Complete-Action -Action $A -Success $false -Detail 'No Wi-Fi'
}
if ($svc.Status -ne 'Running') { Write-Warn "WLAN AutoConfig is $($svc.Status) - start it with 'Restart Wi-Fi (WLAN) service'." }

Write-Header '1. Current connection'
$w = @(Get-WifiInterfaceInfo)
if ($w.Count -eq 0) { Write-Warn 'No Wi-Fi interface reported (Wi-Fi switched off, adapter disabled or driver missing).' }
foreach ($i in $w) {
    Write-KV 'Interface' $i.Name
    Write-KV 'State' $i.State
    if ($i.State -eq 'connected') {
        Write-KV 'SSID' $i.SSID
        Write-KV 'BSSID (AP)' $i.BSSID
        Write-KV 'Signal' $i.Signal
        Write-KV 'Radio type' $i.'Radio type'
        Write-KV 'Channel' $i.Channel
        Write-KV 'Authentication' $i.Authentication
        Write-KV 'Receive rate' $i.'Receive rate (Mbps)'
        Write-KV 'Transmit rate' $i.'Transmit rate (Mbps)'
        Write-KV 'Profile' $i.Profile
        $sig = 0
        if ($i.Signal -match '(\d+)') { $sig = [int]$Matches[1] }
        if ($sig -gt 0 -and $sig -lt 40) { Write-Warn 'Weak signal - move closer to the access point.' }
    }
    Write-Host ''
}

Write-Header '2. Saved Wi-Fi profiles (names only)'
$prof = @(& netsh.exe wlan show profiles 2>$null | ForEach-Object { if ($_ -match 'All User Profile\s*:\s*(.+)$') { $Matches[1].Trim() } })
if ($prof.Count -eq 0) { Write-Info 'No saved profiles' } else { $prof | ForEach-Object { Write-Host "  $_" } }
Write-Host ''

Write-Header '3. Nearby networks (strongest signal first)'
$near = @(Get-WifiNearby)
if ($near.Count -eq 0) { Write-Warn 'Could not list nearby networks (Wi-Fi off, no adapter, or Windows location permission is off).' }
else { Write-Table ($near | Select-Object -First 25) }
Complete-Action -Action $A -Success ($w.Count -gt 0) -Detail "$($w.Count) interface(s)"

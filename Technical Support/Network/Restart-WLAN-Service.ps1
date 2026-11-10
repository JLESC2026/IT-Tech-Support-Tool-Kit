$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'Restart Wi-Fi (WLAN AutoConfig) service'
Write-Header $A
Assert-Admin $A
$ok = $false
try {
    $r = Restart-ServiceByName -Name 'WlanSvc' -Label 'WLAN AutoConfig'
    if ($null -eq $r) {
        Write-Warn 'This PC has no Wi-Fi adapter (WLAN AutoConfig is not installed).'
    } elseif ($r) {
        $ok = $true
        Start-Sleep -Seconds 4
        $w = @(Get-WifiInterfaceInfo)
        if ($w.Count -eq 0) { Write-Warn 'Service is running but no Wi-Fi interface was reported (Wi-Fi turned off or adapter disabled?).' }
        foreach ($i in $w) { Write-Info "Wi-Fi '$($i.Name)': $($i.State) $(if ($i.SSID) { '- ' + $i.SSID })" }
    }
} catch {
    Write-Fail $_.Exception.Message
}
Complete-Action -Action $A -Success $ok

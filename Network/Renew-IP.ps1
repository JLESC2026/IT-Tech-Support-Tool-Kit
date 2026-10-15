$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'Renew IP address (DHCP)'
Write-Header $A
Assert-Admin $A
$ok = $false
try {
    $before = Get-PrimaryNetwork
    if ($before) { Write-Info "Current address: $($before.IPv4) on $($before.Adapter) ($($before.DHCP) DHCP)" }
    else { Write-Warn 'No active adapter with an IP address right now.' }

    Write-Warn 'The network connection will drop for a few seconds.'
    Write-Info 'Releasing the current address...'
    [void](Invoke-Native -FilePath 'ipconfig.exe' -Arguments @('/release'))
    Start-Sleep -Seconds 2
    Write-Info 'Requesting a new address...'
    $code = Invoke-Native -FilePath 'ipconfig.exe' -Arguments @('/renew')
    if ($code -ne 0) { Write-Warn "ipconfig /renew returned code $code (adapters without a DHCP server or without a cable report an error - that is normal)." }

    $ip = ''
    for ($i = 0; $i -lt 8; $i++) {
        Start-Sleep -Seconds 2
        $after = Get-PrimaryNetwork
        if ($after -and $after.IPv4List.Count -gt 0) { $ip = [string]$after.IPv4List[0]; if ($ip -notlike '169.254.*') { break } }
    }
    if ($ip -and $ip -notlike '169.254.*') {
        $ok = $true
        Write-Ok "New address: $ip (gateway: $($after.Gateway), DNS: $($after.DNS))"
    } elseif ($ip) {
        Write-Fail "Only a self-assigned address ($ip) was obtained - the DHCP server did not answer."
    } else {
        Write-Fail 'No IPv4 address after renewing - check the cable / Wi-Fi connection.'
    }
} catch {
    Write-Fail $_.Exception.Message
}
Complete-Action -Action $A -Success $ok

$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'Bluetooth devices'
Write-Header $A
$issues = 0
try {
    Write-Header '1. Bluetooth service'
    $s = Get-Service -Name bthserv -ErrorAction SilentlyContinue
    if (-not $s) { Write-Warn 'Bluetooth Support Service is not installed (no Bluetooth hardware?)'; $issues++ }
    elseif ($s.Status -eq 'Running') { Write-Ok "Bluetooth Support Service: Running ($($s.StartType))" }
    else { Write-Warn "Bluetooth Support Service: $($s.Status) ($($s.StartType)) - it normally starts on demand; use 'Restart Bluetooth'" }
    Write-Host ''

    Write-Header '2. Bluetooth adapter'
    $bt = @(Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue)
    $radio = @($bt | Where-Object { $_.InstanceId -match '^(USB|PCI|ACPI|ROOT)\\' -and $_.FriendlyName -notmatch 'Enumerator|Service|Protocol|Transport|RFCOMM|LE Generic' })
    if ($radio.Count -eq 0) {
        Write-Fail 'No Bluetooth adapter found (driver missing, adapter disabled, or the PC has no Bluetooth)'
        $issues++
    }
    foreach ($r in $radio) {
        if ($r.Status -eq 'OK') { Write-Ok $r.FriendlyName } else { Write-Fail "$($r.FriendlyName)  [$($r.Status)]"; $issues++ }
    }
    Write-Host ''

    Write-Header '3. Paired / connected Bluetooth devices'
    $paired = @($bt | Where-Object { $_.InstanceId -like 'BTHENUM\DEV_*' -or $_.InstanceId -like 'BTHLE\DEV_*' })
    $names = @($paired | Where-Object { $_.FriendlyName } | Sort-Object FriendlyName)
    if ($names.Count -eq 0) { Write-Info 'No paired devices' }
    foreach ($p in $names) {
        if ($p.Status -eq 'OK') { Write-Ok $p.FriendlyName } else { Write-Info "$($p.FriendlyName)  [$($p.Status) - not connected right now]" }
    }
    Write-Host ''
    Write-Info 'If a device will not connect: remove it in Bluetooth settings, put it in pairing mode and add it again.'
} catch {
    Write-Fail $_.Exception.Message
    $issues++
}
Write-Host ''
if ($issues -eq 0) { Write-Ok 'Bluetooth looks healthy' } else { Write-Warn "$issues issue(s) found" }
Complete-Action -Action $A -Success ($issues -eq 0) -Detail "$issues issue(s)"

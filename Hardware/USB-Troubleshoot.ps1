$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'USB troubleshooting'
Write-Header $A
Write-Info 'Read-only checks - nothing is changed on this computer.'
$issues = 0
try {
    Write-Host ''
    Write-Header '1. USB storage driver (USBSTOR)'
    $start = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR' -Name Start -ErrorAction SilentlyContinue).Start
    if ($null -eq $start) { Write-Warn 'USBSTOR service entry not found'; $issues++ }
    elseif ([int]$start -eq 4) { Write-Fail 'USB storage is DISABLED by policy/registry (USBSTOR Start = 4). Flash drives will not work.'; $issues++ }
    else { Write-Ok "USBSTOR is enabled (Start = $start)" }
    $deny = (Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices' -ErrorAction SilentlyContinue)
    if ($deny -and $deny.Deny_All) { Write-Warn 'A group policy denies access to removable storage (Deny_All).'; $issues++ }

    Write-Host ''
    Write-Header '2. Devices with errors'
    $bad = @(Get-CimInstance Win32_PnPEntity -ErrorAction Stop | Where-Object { ($_.PNPDeviceID -like 'USB*') -and ([int]$_.ConfigManagerErrorCode -ne 0) })
    if ($bad.Count -eq 0) { Write-Ok 'No USB device reports an error' }
    foreach ($b in $bad) { Write-Fail "$($b.Name): $(Get-DeviceProblemText $b.ConfigManagerErrorCode)"; $issues++ }

    Write-Host ''
    Write-Header '3. USB selective suspend (power saving)'
    $out = & powercfg.exe /query SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 2>&1 | Out-String
    $ac = $null; $dc = $null
    if ($out -match 'Current AC Power Setting Index:\s*0x([0-9a-fA-F]+)') { $ac = [Convert]::ToInt32($Matches[1], 16) }
    if ($out -match 'Current DC Power Setting Index:\s*0x([0-9a-fA-F]+)') { $dc = [Convert]::ToInt32($Matches[1], 16) }
    if ($null -eq $ac) { Write-Info 'Could not read the setting' }
    elseif ($ac -eq 1 -or $dc -eq 1) {
        Write-Warn 'Selective suspend is ENABLED - Windows may power down USB ports and devices (mouse, scanners, printers) drop out.'
        Write-Info '  To turn it off: Control Panel > Power Options > Change plan settings > Advanced > USB settings.'
        $issues++
    } else { Write-Ok 'Selective suspend is disabled' }

    Write-Host ''
    Write-Header '4. USB storage state'
    $usbDisks = @(Get-Disk -ErrorAction SilentlyContinue | Where-Object { $_.BusType -eq 'USB' })
    if ($usbDisks.Count -eq 0) { Write-Info 'No USB storage connected right now' }
    foreach ($d in $usbDisks) {
        $parts = @(Get-Partition -DiskNumber $d.Number -ErrorAction SilentlyContinue)
        $withLetter = @($parts | Where-Object { $_.DriveLetter })
        if ($d.IsOffline) { Write-Warn "$($d.FriendlyName): OFFLINE - bring online in Disk Management"; $issues++ }
        elseif ($d.PartitionStyle -eq 'RAW') { Write-Warn "$($d.FriendlyName): RAW / not initialised or unreadable file system - do not format until data is checked"; $issues++ }
        elseif ($withLetter.Count -eq 0) { Write-Warn "$($d.FriendlyName): no drive letter - assign one in Disk Management"; $issues++ }
        else { Write-Ok "$($d.FriendlyName): $(($withLetter | ForEach-Object { $_.DriveLetter + ':' }) -join ' ') $(Format-Size $d.Size)" }
    }

    Write-Host ''
    Write-Header '5. What to try next'
    Write-Host '  - Try another USB port (rear ports on desktops), without a hub or extension cable.'
    Write-Host '  - Unplug the device, wait 10 seconds, plug it in again; try it on another PC.'
    Write-Host '  - Use "Rescan hardware" in the Hardware menu, then check Device Manager.'
    Write-Host '  - Shut the PC down fully (not just restart) to reset the USB controller.'
    Write-Host '  - Update chipset / USB controller drivers from the PC manufacturer.'
} catch {
    Write-Fail $_.Exception.Message
    $issues++
}
Write-Host ''
if ($issues -eq 0) { Write-Ok 'No USB configuration problems found' } else { Write-Warn "$issues issue(s) found" }
Complete-Action -Action $A -Success ($issues -eq 0) -Detail "$issues issue(s)"

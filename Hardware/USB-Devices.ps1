$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'USB devices'
Write-Header $A
$issues = 0
try {
    Write-Header '1. USB devices Windows can see'
    $usb = @(Get-CimInstance Win32_PnPEntity -ErrorAction Stop | Where-Object { $_.PNPDeviceID -like 'USB\*' -or $_.PNPDeviceID -like 'USBSTOR\*' })
    $hubs = @($usb | Where-Object { $_.Name -match 'Hub|Host Controller|Root' })
    $devs = @($usb | Where-Object { $_.Name -notmatch 'Hub|Host Controller|Root' })
    Write-Info "$($devs.Count) USB device(s), $($hubs.Count) hub/controller entries"
    foreach ($d in ($devs | Sort-Object Name)) {
        $line = "$($d.Name)  [$($d.PNPClass)]"
        if ([int]$d.ConfigManagerErrorCode -ne 0) { Write-Fail "$line - $(Get-DeviceProblemText $d.ConfigManagerErrorCode)"; $issues++ }
        else { Write-Ok $line }
    }
    Write-Host ''

    Write-Header '2. USB storage (flash drives, external disks)'
    $usbDisks = @(Get-Disk -ErrorAction SilentlyContinue | Where-Object { $_.BusType -eq 'USB' })
    if ($usbDisks.Count -eq 0) { Write-Info 'No USB storage connected' }
    foreach ($disk in $usbDisks) {
        $letters = @(Get-Partition -DiskNumber $disk.Number -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter } | ForEach-Object { "$($_.DriveLetter):" })
        $txt = "$($disk.FriendlyName)  $(Format-Size $disk.Size)  $($disk.PartitionStyle)  drive: $(if ($letters.Count) { $letters -join ' ' } else { '(none)' })"
        if ($disk.IsOffline) { Write-Warn "$txt - disk is OFFLINE (bring it online in Disk Management)"; $issues++ }
        elseif ($letters.Count -eq 0) { Write-Warn "$txt - no drive letter (assign one in Disk Management)"; $issues++ }
        else { Write-Ok $txt }
    }
    Write-Host ''

    Write-Header '3. Unknown / failed USB devices'
    $bad = @($usb | Where-Object { [int]$_.ConfigManagerErrorCode -ne 0 -or $_.Name -like 'Unknown USB Device*' })
    if ($bad.Count -eq 0) { Write-Ok 'None' }
    foreach ($b in $bad) {
        Write-Warn "$($b.Name) - $(Get-DeviceProblemText $b.ConfigManagerErrorCode)"
        if ($b.Name -like 'Unknown USB Device*') { Write-Info '  Usually a bad cable/port, an under-powered hub, or a faulty device. Try another port without a hub.' }
    }
} catch {
    Write-Fail $_.Exception.Message
    $issues++
}
Write-Host ''
if ($issues -eq 0) { Write-Ok 'No USB problems detected' } else { Write-Warn "$issues issue(s) found - see messages above (try 'USB troubleshooting')" }
Complete-Action -Action $A -Success ($issues -eq 0) -Detail "$issues issue(s)"

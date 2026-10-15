$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'Connected devices'
Write-Header $A
$ok = $false
try {
    $all = @(Get-PnpDevice -PresentOnly -ErrorAction Stop)
    $groups = [ordered]@{
        'Keyboards'             = 'Keyboard'
        'Mice and pointing'     = 'Mouse'
        'Monitors'              = 'Monitor'
        'Cameras / imaging'     = 'Camera', 'Image'
        'Printers'              = 'Printer', 'PrintQueue'
        'Phones / portable'     = 'WPD', 'PortableDevice'
        'Bluetooth'             = 'Bluetooth'
        'Smart card readers'    = 'SmartCardReader'
        'Audio endpoints'       = 'AudioEndpoint'
        'Disk drives'           = 'DiskDrive'
    }
    $shownIds = @{}
    foreach ($label in $groups.Keys) {
        $classes = @($groups[$label])
        $items = @($all | Where-Object { $classes -contains $_.Class -and $_.FriendlyName })
        if ($items.Count -eq 0) { continue }
        Write-Header "$label ($($items.Count))"
        foreach ($i in ($items | Sort-Object FriendlyName)) {
            $shownIds[$i.InstanceId] = $true
            $line = $i.FriendlyName
            if ($i.Status -eq 'OK') { Write-Ok $line } else { Write-Warn "$line  [$($i.Status)]" }
        }
        Write-Host ''
    }
    $usbOther = @($all | Where-Object { $_.InstanceId -like 'USB\*' -and -not $shownIds.ContainsKey($_.InstanceId) -and $_.FriendlyName -notmatch 'Hub|Host Controller|Root' })
    if ($usbOther.Count -gt 0) {
        Write-Header "Other USB devices ($($usbOther.Count))"
        foreach ($i in ($usbOther | Sort-Object FriendlyName)) {
            if ($i.Status -eq 'OK') { Write-Ok $i.FriendlyName } else { Write-Warn "$($i.FriendlyName)  [$($i.Status)]" }
        }
        Write-Host ''
    }
    Write-Info "$($all.Count) present device entries in total (full list: Device Manager)."
    $ok = $true
} catch {
    Write-Fail $_.Exception.Message
}
Complete-Action -Action $A -Success $ok

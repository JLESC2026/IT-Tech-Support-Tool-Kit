$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'Storage information'
Write-Header $A
$issues = 0
try {
    Write-Header '1. Physical disks'
    $pds = @(Get-PhysicalDisk -ErrorAction Stop | Sort-Object DeviceId)
    foreach ($p in $pds) {
        $line = "{0}  |  {1}  |  {2}  |  {3}  |  {4}" -f $p.FriendlyName, $p.MediaType, $p.BusType, (Format-Size $p.Size), ((@($p.OperationalStatus) | ForEach-Object { [string]$_ }) -join '/')
        if ($p.HealthStatus -eq 'Healthy') { Write-Ok "$line  |  Healthy" }
        elseif ($p.HealthStatus -eq 'Warning') { Write-Warn "$line  |  WARNING - back up data now"; $issues++ }
        else { Write-Fail "$line  |  $($p.HealthStatus) - back up data and replace the disk"; $issues++ }
    }
    Write-Host ''

    Write-Header '2. Disks (partitioning / online state)'
    foreach ($d in @(Get-Disk -ErrorAction SilentlyContinue | Sort-Object Number)) {
        $line = "Disk $($d.Number): $($d.FriendlyName)  $(Format-Size $d.Size)  $($d.PartitionStyle)  $($d.BusType)"
        if ($d.IsOffline) { Write-Warn "$line - OFFLINE ($($d.OfflineReason))"; $issues++ }
        elseif ($d.IsReadOnly) { Write-Warn "$line - READ-ONLY"; $issues++ }
        else { Write-Ok $line }
    }
    Write-Host ''

    Write-Header '3. Volumes and free space'
    foreach ($v in @(Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter } | Sort-Object DriveLetter)) {
        if (-not $v.Size) { Write-Info "$($v.DriveLetter):  $($v.DriveType) (no media)"; continue }
        $pct = [math]::Round(($v.SizeRemaining / $v.Size) * 100, 1)
        $line = "{0}:  {1,-12} {2,-6} {3} free of {4} ({5} % free)" -f $v.DriveLetter, $v.FileSystemLabel, $v.FileSystem, (Format-Size $v.SizeRemaining), (Format-Size $v.Size), $pct
        if ($v.HealthStatus -and $v.HealthStatus -ne 'Healthy') { Write-Fail "$line - volume health: $($v.HealthStatus)"; $issues++ }
        elseif ($pct -lt 5) { Write-Fail "$line - almost full"; $issues++ }
        elseif ($pct -lt 10) { Write-Warn "$line - low space"; $issues++ }
        else { Write-Ok $line }
    }
    Write-Host ''

    Write-Header '4. Reliability counters (temperature, wear, errors)'
    $rel = @($pds | ForEach-Object {
        $c = $_ | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
        if ($c) {
            [pscustomobject]@{ Disk = $_.FriendlyName; 'Temp C' = $c.Temperature; 'Wear %' = $c.Wear; 'Power-on h' = $c.PowerOnHours; 'Read errors' = $c.ReadErrorsTotal; 'Write errors' = $c.WriteErrorsTotal }
        }
    })
    if ($rel.Count -eq 0) { Write-Info 'Not available (needs administrator rights, or the drive does not report it). Full SMART data: Advanced section.' }
    else {
        Write-Table $rel
        foreach ($r in $rel) {
            if ($r.'Read errors' -gt 0 -or $r.'Write errors' -gt 0) { Write-Warn "$($r.Disk) has recorded read/write errors"; $issues++ }
            if ($null -ne $r.'Wear %' -and $r.'Wear %' -ge 80) { Write-Warn "$($r.Disk) wear is $($r.'Wear %') % - plan a replacement"; $issues++ }
        }
    }
} catch {
    Write-Fail $_.Exception.Message
    $issues++
}
Write-Host ''
if ($issues -eq 0) { Write-Ok 'Storage looks healthy' } else { Write-Warn "$issues issue(s) found" }
Complete-Action -Action $A -Success ($issues -eq 0) -Detail "$issues issue(s)"

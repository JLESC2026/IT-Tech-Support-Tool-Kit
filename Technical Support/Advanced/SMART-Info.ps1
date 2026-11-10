# SMART information - drive health prediction and the key SMART attributes.
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'SMART information'
Write-Header $A
Assert-Admin $A
$issues = 0
try {
    Write-Header '1. Physical disk health'
    foreach ($p in @(Get-PhysicalDisk -ErrorAction Stop | Sort-Object DeviceId)) {
        $line = "{0} | {1} | {2} | {3}" -f $p.FriendlyName, $p.MediaType, $p.BusType, (Format-Size $p.Size)
        if ($p.HealthStatus -eq 'Healthy') { Write-Ok "$line | Healthy" }
        elseif ($p.HealthStatus -eq 'Warning') { Write-Warn "$line | WARNING - back up data now"; $issues++ }
        else { Write-Fail "$line | $($p.HealthStatus) - back up data and replace the disk"; $issues++ }
        $c = $p | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
        if ($c) {
            Write-Host ("    Temperature: {0} C   Wear: {1} %   Power-on hours: {2}   Read errors: {3}   Write errors: {4}" -f $c.Temperature, $c.Wear, $c.PowerOnHours, $c.ReadErrorsTotal, $c.WriteErrorsTotal)
        }
    }
    Write-Host ''

    Write-Header '2. SMART failure prediction (ATA / SATA drives)'
    $pred = @()
    try { $pred = @(Get-CimInstance -Namespace root\wmi -ClassName MSStorageDriver_FailurePredictStatus -ErrorAction Stop) } catch { }
    if ($pred.Count -eq 0) {
        Write-Info 'Not reported by this system (normal for NVMe drives, USB drives and some RAID controllers).'
    }
    foreach ($d in $pred) {
        if ($d.PredictFailure) { Write-Fail "$($d.InstanceName): drive predicts FAILURE - back up now and replace it"; $issues++ }
        else { Write-Ok "$($d.InstanceName): no failure predicted" }
    }
    Write-Host ''

    Write-Header '3. Key SMART attributes'
    $names = @{
        1 = 'Read error rate'; 5 = 'Reallocated sectors'; 9 = 'Power-on hours'; 12 = 'Power cycles'; 177 = 'Wear leveling count';
        187 = 'Reported uncorrectable errors'; 188 = 'Command timeout'; 194 = 'Temperature'; 196 = 'Reallocation events';
        197 = 'Pending sectors'; 198 = 'Offline uncorrectable'; 199 = 'Interface CRC errors'; 231 = 'SSD life left'; 233 = 'Media wearout'
    }
    $watch = 5, 187, 196, 197, 198
    $data = @()
    try { $data = @(Get-CimInstance -Namespace root\wmi -ClassName MSStorageDriver_FailurePredictData -ErrorAction Stop) } catch { }
    if ($data.Count -eq 0) { Write-Info 'No SMART attribute table available for this system.' }
    foreach ($d in $data) {
        Write-Host $d.InstanceName
        $v = $d.VendorSpecific
        $rows = @()
        for ($i = 0; $i -lt 30; $i++) {
            $o = 2 + ($i * 12)
            if ($o + 11 -ge $v.Length) { break }
            $id = [int]$v[$o]
            if ($id -eq 0) { continue }
            $raw = [long]0
            for ($b = 5; $b -ge 0; $b--) { $raw = ($raw * 256) + [long]$v[$o + 5 + $b] }
            $label = "Attribute $id"
            if ($names.ContainsKey($id)) { $label = $names[$id] }
            $rows += [pscustomobject]@{ ID = $id; Attribute = $label; Value = [int]$v[$o + 3]; Worst = [int]$v[$o + 4]; Raw = $raw }
            if (($watch -contains $id) -and $raw -gt 0) { Write-Warn "$label is $raw (should be 0) - watch this drive closely"; $issues++ }
        }
        $show = @($rows | Where-Object { $names.ContainsKey($_.ID) })
        if ($show.Count -gt 0) { Write-Table $show }
    }
} catch {
    Write-Fail $_.Exception.Message
    $issues++
}
Write-Host ''
if ($issues -eq 0) { Write-Ok 'No SMART warnings' } else { Write-Warn "$issues warning(s) - back up important data" }
Complete-Action -Action $A -Success ($issues -eq 0) -Detail "$issues warning(s)"

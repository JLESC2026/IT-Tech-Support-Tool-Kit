$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'Hardware information'
Write-Header $A
$ok = $false
try {
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    $bios = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue
    $board = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue
    $enc = Get-CimInstance Win32_SystemEnclosure -ErrorAction SilentlyContinue
    $laptopTypes = 8, 9, 10, 11, 12, 14, 18, 21, 30, 31, 32
    $kind = 'Desktop / other'
    if ($enc -and (@($enc.ChassisTypes) | Where-Object { $laptopTypes -contains [int]$_ })) { $kind = 'Laptop / portable' }

    Write-Header 'System'
    Write-KV 'Manufacturer' $cs.Manufacturer
    Write-KV 'Model' $cs.Model
    Write-KV 'Type' $kind
    Write-KV 'Serial number' $bios.SerialNumber
    Write-KV 'Motherboard' ("$($board.Manufacturer) $($board.Product)").Trim()
    Write-KV 'BIOS' "$($bios.SMBIOSBIOSVersion)  ($(Format-Date $bios.ReleaseDate))"
    Write-Host ''

    Write-Header 'Processor'
    foreach ($c in @(Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue)) {
        Write-KV 'CPU' ([string]$c.Name).Trim()
        Write-KV 'Cores / threads' "$($c.NumberOfCores) / $($c.NumberOfLogicalProcessors)"
        Write-KV 'Max speed' "$($c.MaxClockSpeed) MHz"
    }
    Write-Host ''

    Write-Header 'Memory'
    Write-KV 'Installed RAM' (Format-Size $cs.TotalPhysicalMemory)
    foreach ($m in @(Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue)) {
        Write-Host ("  {0,-14} {1,-9} {2,5} MHz  {3} {4}" -f $m.BankLabel, (Format-Size $m.Capacity), $m.Speed, $m.Manufacturer, ([string]$m.PartNumber).Trim())
    }
    Write-Host ''

    Write-Header 'Graphics'
    foreach ($g in @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)) {
        Write-KV 'GPU' $g.Name
        Write-KV 'Driver' "$($g.DriverVersion)  ($(Format-Date $g.DriverDate))"
    }
    Write-Host ''

    Write-Header 'Disks'
    foreach ($d in @(Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue)) {
        Write-Host ("  {0,-45} {1,-10} {2}" -f $d.Model, (Format-Size $d.Size), $d.InterfaceType)
    }
    Write-Host ''

    $bat = @(Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue)
    if ($bat.Count -gt 0) {
        Write-Header 'Battery'
        foreach ($b in $bat) { Write-KV 'Charge' "$($b.EstimatedChargeRemaining) %  (status code $($b.BatteryStatus))" }
        Write-Info 'Wear level: run "powercfg /batteryreport" from an admin prompt for the full report.'
        Write-Host ''
    }
    $ok = $true
} catch {
    Write-Fail $_.Exception.Message
}
Complete-Action -Action $A -Success $ok

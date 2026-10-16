# System diagnostics - computer facts, uptime, pending restart, memory hogs, recent updates.
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
. (Join-Path $root 'Launcher\Part4-Helpers.ps1')
$A = 'System diagnostics'
Write-Header $A
$issues = 0
try {
    Write-Header '1. Computer information'
    Write-Host (Get-ComputerInfoText)
    Write-Host ''

    Write-Header '2. Uptime and memory'
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $up = (Get-Date) - $os.LastBootUpTime
    $line = "Up for {0}d {1}h {2}m (last boot {3})" -f $up.Days, $up.Hours, $up.Minutes, (Format-Date $os.LastBootUpTime 'yyyy-MM-dd HH:mm')
    if ($up.TotalDays -ge 14) { Write-Warn "$line - a restart is recommended"; $issues++ } else { Write-Ok $line }
    $totalKb = [double]$os.TotalVisibleMemorySize
    $freeKb = [double]$os.FreePhysicalMemory
    $freePct = [math]::Round(($freeKb / $totalKb) * 100, 1)
    $mem = "Memory: {0} free of {1} ({2} % free)" -f (Format-Size ($freeKb * 1KB)), (Format-Size ($totalKb * 1KB)), $freePct
    if ($freePct -lt 10) { Write-Warn $mem; $issues++ } else { Write-Ok $mem }
    Write-Host ''

    Write-Header '3. System drive space'
    $vol = Get-Volume -DriveLetter $env:SystemDrive.TrimEnd(':') -ErrorAction SilentlyContinue
    if ($vol) {
        $pct = [math]::Round(($vol.SizeRemaining / $vol.Size) * 100, 1)
        $l = "$($env:SystemDrive) $(Format-Size $vol.SizeRemaining) free of $(Format-Size $vol.Size) ($pct % free)"
        if ($pct -lt 10) { Write-Warn $l; $issues++ } else { Write-Ok $l }
    }
    Write-Host ''

    Write-Header '4. Pending restart'
    $pending = @()
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') { $pending += 'component servicing' }
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') { $pending += 'Windows Update' }
    if ($pending.Count -gt 0) { Write-Warn ('Restart pending: ' + ($pending -join ', ')); $issues++ } else { Write-Ok 'No pending restart detected' }
    Write-Host ''

    Write-Header '5. Top 8 processes by memory'
    Write-Table (Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 8 Name, Id, @{ n = 'Memory'; e = { Format-Size $_.WorkingSet64 } })
    Write-Host ''

    Write-Header '6. Latest installed updates'
    $hf = @(Get-HotFix -ErrorAction SilentlyContinue | Sort-Object InstalledOn -Descending | Select-Object -First 8)
    if ($hf.Count -eq 0) { Write-Info 'No update history available' } else { Write-Table ($hf | Select-Object HotFixID, Description, InstalledOn) }
} catch {
    Write-Fail $_.Exception.Message
    $issues++
}
Write-Host ''
if ($issues -eq 0) { Write-Ok 'No system issues detected' } else { Write-Warn "$issues item(s) need attention" }
Complete-Action -Action $A -Success ($issues -eq 0) -Detail "$issues item(s)"

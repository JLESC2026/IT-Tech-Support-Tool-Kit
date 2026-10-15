. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
$A = 'Check printer status'
Write-Header $A

$sp = Get-Service -Name 'Spooler' -ErrorAction SilentlyContinue
if ($sp -and $sp.Status -eq 'Running') { Write-Ok 'Print Spooler is running' }
else { Write-Fail 'Print Spooler is NOT running - printing cannot work. Use "Restart Print Spooler".' }

$printers = @(Get-CimInstance -ClassName Win32_Printer -ErrorAction SilentlyContinue)
$problems = 0
if ($printers.Count -eq 0) {
    Write-Fail 'No printers installed'
    $problems++
}
foreach ($p in ($printers | Sort-Object Name)) {
    $jobs = 0
    try { $jobs = @(Get-PrintJob -PrinterName $p.Name -ErrorAction Stop).Count } catch { }
    $statusText = Get-PrinterStatusText $p.PrinterStatus
    $errText = Get-PrinterErrorText $p.DetectedErrorState
    $bad = ($p.WorkOffline -or $p.PrinterStatus -in 6, 7 -or $p.DetectedErrorState -in 4, 6, 7, 8, 9, 10)
    $line = "$($p.Name) | $statusText | error: $errText | queued jobs: $jobs"
    if ($bad) { Write-Warn $line; $problems++ } else { Write-Ok $line }
    if ($p.WorkOffline) { Write-Info '    Printer is set to "Use Printer Offline" - untick it in the printer window.' }
    if ($jobs -gt 0 -and $p.PrinterStatus -ne 4) { Write-Info "    $jobs job(s) waiting but the printer is not printing - the queue may be stuck." }
}
Write-Host ''
if ($problems -eq 0) { Write-Ok 'No printer problems detected' } else { Write-Warn "$problems printer problem(s) found" }
Complete-Action -Action $A -Success ($problems -eq 0) -Detail "$problems problem(s)"

. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
$A = 'Printer diagnostics'
Write-Header $A
$issues = 0

Write-Host ''
Write-Header '1. Print services'
foreach ($svcName in 'Spooler', 'PrintNotify') {
    $s = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if (-not $s) { Write-Warn "$svcName : not installed" }
    elseif ($s.Status -eq 'Running') { Write-Ok "$($s.DisplayName): Running ($($s.StartType))" }
    elseif ($svcName -eq 'Spooler') { Write-Fail "$($s.DisplayName): $($s.Status) ($($s.StartType))"; $issues++ }
    else { Write-Warn "$($s.DisplayName): $($s.Status) ($($s.StartType))" }
}

Write-Host ''
Write-Header '2. Printers'
$printers = @(Get-CimInstance -ClassName Win32_Printer -ErrorAction SilentlyContinue)
if ($printers.Count -eq 0) { Write-Fail 'No printers installed'; $issues++ }
foreach ($p in ($printers | Sort-Object Name)) {
    $jobs = 0
    try { $jobs = @(Get-PrintJob -PrinterName $p.Name -ErrorAction Stop).Count } catch { }
    $line = "$($p.Name) | $(Get-PrinterStatusText $p.PrinterStatus) | $(Get-PrinterErrorText $p.DetectedErrorState) | jobs: $jobs | port: $($p.PortName)$(if ($p.Default) { ' | DEFAULT' })"
    if ($p.WorkOffline -or $p.PrinterStatus -in 6, 7) { Write-Warn $line; $issues++ } else { Write-Ok $line }
}

Write-Host ''
Write-Header '3. Spool folder'
$spool = Join-Path $env:SystemRoot 'System32\spool\PRINTERS'
$files = @(Get-ChildItem -LiteralPath $spool -Force -ErrorAction SilentlyContinue)
if ($files.Count -gt 0) { Write-Warn "$($files.Count) file(s) in the spool folder - jobs may be stuck (use 'Clear print queue')"; $issues++ }
else { Write-Ok 'Spool folder is empty' }

Write-Host ''
Write-Header '4. Drivers'
$drivers = @(Get-PrinterDriver -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
foreach ($p in $printers) {
    if ($p.DriverName -and ($drivers -notcontains $p.DriverName)) { Write-Fail "$($p.Name): driver '$($p.DriverName)' missing"; $issues++ }
}
Write-Info "$($drivers.Count) driver(s) installed"

Write-Host ''
Write-Header '5. Recent print errors (PrintService log)'
try {
    $ev = @(Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-PrintService/Admin'; Level = 1, 2, 3 } -MaxEvents 8 -ErrorAction Stop)
    if ($ev.Count -eq 0) { Write-Ok 'No recent warnings or errors' }
    foreach ($e in $ev) {
        $msg = ($e.Message -split "`r?`n")[0]
        Write-Warn "$($e.TimeCreated.ToString('yyyy-MM-dd HH:mm')) [ID $($e.Id)] $msg"
    }
} catch {
    Write-Info 'No PrintService events found (the log may be empty or disabled)'
}

Write-Host ''
if ($issues -eq 0) { Write-Ok 'No printer issues detected' } else { Write-Warn "$issues issue(s) found - see messages above" }
Complete-Action -Action $A -Success ($issues -eq 0) -Detail "$issues issue(s)"

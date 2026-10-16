# Generate a complete diagnostic report: Reports\COMPUTERNAME_DATE\*.txt
param([switch]$NoOpen)
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
. (Join-Path $root 'Launcher\Part4-Helpers.ps1')
$A = 'Generate diagnostic report'
Write-Header $A
if (-not (Test-IsAdmin)) {
    Write-Warn 'Not running as administrator - SMART data, some event logs and some driver details may be missing from the report.'
}
$failed = 0
try {
    $dir = New-ReportFolder
    Write-Info "Report folder: $dir"
    Write-Info 'This takes about 30-90 seconds. Please wait...'
    Write-Host ''
    $sections = @(
        @{ File = 'System.txt';    Label = 'System';     Code = { Get-ReportSystemText } },
        @{ File = 'Network.txt';   Label = 'Network';    Code = { Get-ReportNetworkText } },
        @{ File = 'Printers.txt';  Label = 'Printers';   Code = { Get-ReportPrintersText } },
        @{ File = 'Scanners.txt';  Label = 'Scanners';   Code = { Get-ReportScannersText } },
        @{ File = 'Services.txt';  Label = 'Services';   Code = { Get-ReportServicesText } },
        @{ File = 'Drivers.txt';   Label = 'Drivers';    Code = { Get-ReportDriversText } },
        @{ File = 'Disks.txt';     Label = 'Disks';      Code = { Get-ReportDisksText } },
        @{ File = 'EventLogs.txt'; Label = 'Event logs'; Code = { Get-ReportEventLogsText } }
    )
    $i = 0
    foreach ($s in $sections) {
        $i++
        try {
            Write-Info ("[{0}/{1}] {2} ..." -f $i, $sections.Count, $s.Label)
            $text = & $s.Code
            $path = Save-ReportFile -Folder $dir -Name $s.File -Text ([string]$text)
            $size = (Get-Item -LiteralPath $path).Length
            Write-Ok ("{0,-14} {1}" -f $s.File, (Format-Size $size))
        } catch {
            $failed++
            Write-Fail "$($s.File): $($_.Exception.Message)"
        }
    }
    Write-Host ''
    if ($failed -eq 0) { Write-Ok "Report complete: $dir" } else { Write-Warn "Report finished with $failed section(s) missing: $dir" }
    Write-Info 'Zip this folder or copy it to the ticket when escalating.'
    if (-not $NoOpen) { try { Start-Process explorer.exe "`"$dir`"" } catch { } }
} catch {
    Write-Fail $_.Exception.Message
    $failed++
}
Complete-Action -Action $A -Success ($failed -eq 0) -Detail $dir

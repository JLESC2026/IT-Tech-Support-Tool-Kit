# Recent errors from the Windows event logs (System + Application).
param([int]$Days = 7)
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
. (Join-Path $root 'Launcher\Part4-Helpers.ps1')
$A = "Recent errors in the event logs (last $Days days)"
Write-Header $A
$total = 0
foreach ($log in 'System', 'Application') {
    Write-Host ''
    Write-Header "$log log - Critical / Error"
    $r = @(Get-RecentEventRows -LogName $log -Days $Days -Max 25)
    if ($r.Count -eq 0) { Write-Ok 'No critical or error events found'; continue }
    $total += $r.Count
    Write-Table $r
}
Write-Host ''
Write-Info 'Open the full Event Viewer from Diagnostics > Event Viewer for details.'
if ($total -eq 0) { Write-Ok 'Logs are clean' } else { Write-Warn "$total event(s) listed" }
Complete-Action -Action $A -Success $true -Detail "$total event(s)"

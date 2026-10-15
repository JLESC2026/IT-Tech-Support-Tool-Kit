. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
$A = 'Clear print queue'
Write-Header $A
Assert-Admin $A

$spoolDir = Join-Path $env:SystemRoot 'System32\spool\PRINTERS'
$ok = $true
$removed = 0

try {
    $before = @(Get-ChildItem -LiteralPath $spoolDir -Force -ErrorAction SilentlyContinue)
    Write-Info "Found $($before.Count) spool file(s) in the queue folder"

    Write-Info 'Stopping Print Spooler...'
    $r = Restart-ServiceByName -Name 'Spooler' -Label 'Print Spooler' -Mode Stop
    if ($r -ne $true) { throw 'Could not stop the Print Spooler, so the queue was not touched.' }

    foreach ($f in $before) {
        try { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop; $removed++ }
        catch { Write-Warn "Could not delete $($f.Name): $($_.Exception.Message)"; $ok = $false }
    }
    Write-Ok "Deleted $removed spool file(s)"
} catch {
    Write-Fail $_.Exception.Message
    $ok = $false
}

Write-Info 'Starting Print Spooler...'
$r2 = Restart-ServiceByName -Name 'Spooler' -Label 'Print Spooler' -Mode Start
if ($r2 -ne $true) { $ok = $false }
Complete-Action -Action $A -Success $ok -Detail "Deleted $removed file(s)"

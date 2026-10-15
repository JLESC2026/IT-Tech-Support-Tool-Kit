$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'Windows Update repair (reset components)'
Write-Header $A
Assert-Admin $A
Write-Warn 'Stops the update services, renames the SoftwareDistribution and catroot2 folders (Windows rebuilds them), then restarts the services.'
Write-Info 'Update history is kept. Pending downloads are discarded and fetched again.'
$ok = $true
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$svcs = @('wuauserv', 'bits', 'cryptsvc', 'msiserver')
try {
    Write-Header '1. Stop services'
    foreach ($s in $svcs) {
        $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
        if (-not $svc) { Write-Warn "$s is not installed - skipped"; continue }
        if ($svc.Status -eq 'Stopped') { Write-Ok "$s already stopped"; continue }
        try {
            Stop-Service -Name $s -Force -ErrorAction Stop
            $svc.WaitForStatus('Stopped', [TimeSpan]::FromSeconds(30))
            Write-Ok "$s stopped"
        } catch {
            Write-Fail "$s : $($_.Exception.Message)"
            $ok = $false
        }
    }

    Write-Header '2. Clear stuck background transfers'
    try {
        $jobs = @(Get-BitsTransfer -AllUsers -ErrorAction Stop)
        if ($jobs.Count -gt 0) { $jobs | Remove-BitsTransfer -ErrorAction SilentlyContinue; Write-Ok "$($jobs.Count) BITS job(s) removed" }
        else { Write-Ok 'No BITS jobs queued' }
    } catch { Write-Info 'BITS queue not available - skipped' }

    Write-Header '3. Rename update caches'
    $folders = @(
        @{ Path = (Join-Path $env:windir 'SoftwareDistribution'); Name = 'SoftwareDistribution' },
        @{ Path = (Join-Path $env:windir 'System32\catroot2'); Name = 'catroot2' }
    )
    foreach ($f in $folders) {
        if (-not (Test-Path -LiteralPath $f.Path)) { Write-Info "$($f.Name) does not exist - nothing to rename"; continue }
        $newName = "$($f.Name).old-$stamp"
        try {
            Rename-Item -LiteralPath $f.Path -NewName $newName -ErrorAction Stop
            Write-Ok "$($f.Name) renamed to $newName"
        } catch {
            Write-Fail "$($f.Name) could not be renamed: $($_.Exception.Message)"
            $ok = $false
        }
    }

    Write-Header '4. Start services'
    foreach ($s in $svcs) {
        $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
        if (-not $svc) { continue }
        if ($svc.StartType -eq 'Disabled' -and $s -in 'wuauserv', 'bits', 'cryptsvc') {
            try { Set-Service -Name $s -StartupType Manual -ErrorAction Stop; Write-Warn "$s was Disabled - startup type set to Manual" }
            catch { Write-Fail "$s is Disabled and could not be changed: $($_.Exception.Message)"; $ok = $false; continue }
        }
        # msiserver is on-demand; the other three are started now
        if ($s -eq 'msiserver') { continue }
        $r = Restart-ServiceByName -Name $s -Label $s -Mode Start
        if ($r -eq $false) { $ok = $false }
    }

    if ($ok) {
        Write-Host ''
        Write-Info 'Next: open Settings > Windows Update and click "Check for updates".'
        Write-Info "The renamed '*.old-$stamp' folders can be deleted once updates work again."
    }
} catch {
    Write-Fail $_.Exception.Message
    $ok = $false
}
Complete-Action -Action $A -Success $ok

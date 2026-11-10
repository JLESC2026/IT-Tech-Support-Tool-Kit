$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'Rescan hardware'
Write-Header $A
Assert-Admin $A
$ok = $false
try {
    Write-Info 'Asking Windows to re-detect connected hardware (same as "Scan for hardware changes" in Device Manager)...'
    $code = Invoke-Native -FilePath 'pnputil.exe' -Arguments @('/scan-devices')
    if ($code -eq 0) {
        Start-Sleep -Seconds 4
        $bad = @(Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue | Where-Object { [int]$_.ConfigManagerErrorCode -notin 0, 45 })
        $ok = $true
        Write-Ok 'Hardware rescan finished'
        if ($bad.Count -gt 0) { Write-Warn "$($bad.Count) device(s) still report a problem - run 'Problem devices' for details." }
        else { Write-Ok 'No devices report problems' }
    } else {
        Write-Fail "pnputil returned code $code (needs Windows 10 version 1703 or newer)"
    }
} catch {
    Write-Fail $_.Exception.Message
}
Complete-Action -Action $A -Success $ok

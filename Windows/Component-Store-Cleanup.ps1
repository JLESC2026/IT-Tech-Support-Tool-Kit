param([switch]$AnalyzeOnly)
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = $(if ($AnalyzeOnly) { 'Component store analysis' } else { 'Component store cleanup' })
Write-Header $A
Assert-Admin $A
$ok = $false
try {
    Write-Header '1. Analyze the component store (WinSxS)'
    $code = Invoke-Native -FilePath 'dism.exe' -Arguments @('/Online', '/Cleanup-Image', '/AnalyzeComponentStore')
    $t = Get-LastNativeText
    if ($code -ne 0) {
        Write-Fail "dism.exe returned code $code"
    } elseif ($AnalyzeOnly) {
        $ok = $true
        if ($t -match 'Component Store Cleanup Recommended\s*:\s*Yes') { Write-Warn 'Cleanup is recommended - run "Component store cleanup".' }
        else { Write-Ok 'No cleanup needed right now' }
    } else {
        Write-Host ''
        Write-Header '2. Clean up superseded components (/StartComponentCleanup)'
        Write-Info 'Removes superseded versions of updated components. /ResetBase is NOT used, so installed updates can still be uninstalled.'
        $code = Invoke-Native -FilePath 'dism.exe' -Arguments @('/Online', '/Cleanup-Image', '/StartComponentCleanup')
        $ok = ($code -eq 0)
        if ($ok) { Write-Ok 'Component store cleanup finished' } else { Write-Fail "dism.exe returned code $code" }
    }
} catch {
    Write-Fail $_.Exception.Message
}
Complete-Action -Action $A -Success $ok

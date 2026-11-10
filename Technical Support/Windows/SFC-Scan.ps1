param([switch]$VerifyOnly)
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = $(if ($VerifyOnly) { 'SFC verify only (no repair)' } else { 'SFC scan and repair' })
Write-Header $A
Assert-Admin $A
Write-Warn 'This can take 10-30 minutes. Progress is shown every 25 %. Do not close the toolkit or shut the PC down.'
$sfcArg = $(if ($VerifyOnly) { '/verifyonly' } else { '/scannow' })
$ok = $false
try {
    $code = Invoke-Native -FilePath 'sfc.exe' -Arguments @($sfcArg)
    $t = Get-LastNativeText
    if ($t -match 'did not find any integrity violations') {
        $ok = $true
        Write-Ok 'No system file problems found'
    } elseif ($t -match 'found corrupt files and successfully repaired') {
        $ok = $true
        Write-Ok 'Corrupt system files were found and repaired'
        Write-Warn 'Restart the computer to finish the repair.'
    } elseif ($t -match 'found corrupt files but was unable to fix') {
        Write-Fail 'Corrupt files were found but could not be repaired.'
        Write-Info 'Next step: run "DISM RestoreHealth", restart, then run SFC again.'
    } elseif ($t -match 'found integrity violations') {
        Write-Warn 'Integrity violations found (verify-only mode makes no changes).'
        Write-Info 'Run "SFC scan and repair" to fix them.'
    } elseif ($t -match 'could not perform the requested operation|could not start the repair service|pending system repair') {
        Write-Fail 'SFC could not run. Restart the computer (a repair may be pending) and try again.'
    } else {
        $ok = ($code -eq 0)
        if (-not $ok) { Write-Fail "sfc.exe returned code $code" }
    }
    Write-Info "Details are in: $env:windir\Logs\CBS\CBS.log"
} catch {
    Write-Fail $_.Exception.Message
}
Complete-Action -Action $A -Success $ok

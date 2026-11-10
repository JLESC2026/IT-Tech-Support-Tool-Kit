$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'Reset Winsock'
Write-Header $A
Assert-Admin $A
$ok = $false
try {
    Write-Info 'Resetting the Winsock catalog...'
    $code = Invoke-Native -FilePath 'netsh.exe' -Arguments @('winsock', 'reset')
    $ok = ($code -eq 0)
    if ($ok) { Write-Warn 'Restart the computer to finish the Winsock reset.' }
    else { Write-Fail "netsh returned code $code" }
} catch {
    Write-Fail $_.Exception.Message
}
Complete-Action -Action $A -Success $ok -Detail 'Restart required'

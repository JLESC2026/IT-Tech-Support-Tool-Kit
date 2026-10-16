# Opens the Windows Registry Editor (the shortcut asks for confirmation first).
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
$A = 'Open Registry Editor'
Write-Header $A
Write-Warn 'Wrong registry changes can stop Windows from working. Export the key first (File > Export) before editing.'
$ok = $false
try {
    Start-Process -FilePath 'regedit.exe'
    Write-Ok 'Registry Editor opened'
    $ok = $true
} catch {
    Write-Fail $_.Exception.Message
}
Complete-Action -Action $A -Success $ok

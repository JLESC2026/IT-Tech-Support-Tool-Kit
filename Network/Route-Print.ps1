$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'route print'
Write-Header $A
$code = Invoke-Native -FilePath 'route.exe' -Arguments @('print')
$ok = ($code -eq 0)
Complete-Action -Action $A -Success $ok

$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'arp -a'
Write-Header $A
$code = Invoke-Native -FilePath 'arp.exe' -Arguments @('-a')
$ok = ($code -eq 0)
Complete-Action -Action $A -Success $ok

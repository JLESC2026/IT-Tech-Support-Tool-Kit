$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'Test gateway (router)'
Write-Header $A
$res = Invoke-GatewayTest
Write-ResultLines $res.Lines
Complete-Action -Action $A -Success $res.Success

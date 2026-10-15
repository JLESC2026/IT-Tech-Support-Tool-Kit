. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
$A = 'Restart Windows Image Acquisition (WIA)'
Write-Header $A
Assert-Admin $A
$ok = Invoke-ServiceGroup -Services @(@{ Name = 'stisvc'; Label = 'Windows Image Acquisition (WIA)' })
Complete-Action -Action $A -Success $ok

. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
$A = 'Restart Print Spooler'
Write-Header $A
Assert-Admin $A
$ok = Invoke-ServiceGroup -Services @(@{ Name = 'Spooler'; Label = 'Print Spooler' })
Complete-Action -Action $A -Success $ok

. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
$A = 'Restart printer services'
Write-Header $A
Assert-Admin $A
$ok = Invoke-ServiceGroup -Services @(
    @{ Name = 'Spooler';     Label = 'Print Spooler' },
    @{ Name = 'PrintNotify'; Label = 'Printer Extensions and Notifications' },
    @{ Name = 'fdPHost';     Label = 'Function Discovery Provider Host' },
    @{ Name = 'FDResPub';    Label = 'Function Discovery Resource Publication' }
)
Complete-Action -Action $A -Success $ok

. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
$A = 'Restart Windows Audio'
Write-Header $A
Assert-Admin $A
$ok = Invoke-ServiceGroup -Services @(
    @{ Name = 'AudioEndpointBuilder'; Label = 'Windows Audio Endpoint Builder' },
    @{ Name = 'Audiosrv';             Label = 'Windows Audio' }
) -Mode Restart
Complete-Action -Action $A -Success $ok

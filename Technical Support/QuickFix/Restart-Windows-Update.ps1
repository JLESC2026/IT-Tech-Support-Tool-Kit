. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
$A = 'Restart Windows Update services'
Write-Header $A
Assert-Admin $A
$ok = Invoke-ServiceGroup -Services @(
    @{ Name = 'wuauserv'; Label = 'Windows Update' },
    @{ Name = 'BITS';     Label = 'Background Intelligent Transfer Service' },
    @{ Name = 'UsoSvc';   Label = 'Update Orchestrator Service' }
)
Complete-Action -Action $A -Success $ok

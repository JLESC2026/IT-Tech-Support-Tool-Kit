. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
$A = 'Restart scanner services'
Write-Header $A
Assert-Admin $A
$ok = Invoke-ServiceGroup -Services @(
    @{ Name = 'stisvc';           Label = 'Windows Image Acquisition (WIA)' },
    @{ Name = 'ShellHWDetection'; Label = 'Shell Hardware Detection' },
    @{ Name = 'WiaRpc';           Label = 'Still Image Service RPC (WIA)' }
)
Write-Info 'Vendor scan services (for example HP, Epson or Canon scan helpers) can be restarted from the Service Center.'
Complete-Action -Action $A -Success $ok

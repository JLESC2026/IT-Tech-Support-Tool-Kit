. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
$A = 'Restart common Windows services'
Write-Header $A
Assert-Admin $A
Write-Info 'Network services (Wi-Fi, DHCP, DNS) are not included here because they drop the connection - use the Network fixes for those.'
$ok = Invoke-ServiceGroup -Services @(
    @{ Name = 'Spooler';  Label = 'Print Spooler' },
    @{ Name = 'stisvc';   Label = 'Windows Image Acquisition (WIA)' },
    @{ Name = 'Audiosrv'; Label = 'Windows Audio' },
    @{ Name = 'bthserv';  Label = 'Bluetooth Support Service' },
    @{ Name = 'wuauserv'; Label = 'Windows Update' },
    @{ Name = 'BITS';     Label = 'Background Intelligent Transfer Service' }
)
Complete-Action -Action $A -Success $ok

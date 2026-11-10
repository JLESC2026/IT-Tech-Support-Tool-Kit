. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
$A = 'Restart Bluetooth'
Write-Header $A
Assert-Admin $A
$list = @(
    @{ Name = 'bthserv';    Label = 'Bluetooth Support Service' },
    @{ Name = 'BthAvctpSvc'; Label = 'AVCTP Service' },
    @{ Name = 'BTAGService'; Label = 'Bluetooth Audio Gateway Service' }
)
# Per-user Bluetooth service has a random suffix, so find it by pattern
Get-Service -Name 'BluetoothUserService*' -ErrorAction SilentlyContinue | ForEach-Object {
    $list += @{ Name = $_.Name; Label = 'Bluetooth User Support Service' }
}
$ok = Invoke-ServiceGroup -Services $list
Complete-Action -Action $A -Success $ok

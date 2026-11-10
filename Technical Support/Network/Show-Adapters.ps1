$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'Show network adapters'
Write-Header $A
$ok = $false
try {
    $ad = @(Get-NetAdapter -ErrorAction Stop | Sort-Object Status, Name)
    Write-Table ($ad | Select-Object Name, InterfaceDescription, Status, LinkSpeed, MacAddress)
    Write-Host ''
    $down = @($ad | Where-Object { $_.Status -ne 'Up' })
    Write-Info "$($ad.Count) adapter(s): $($ad.Count - $down.Count) up, $($down.Count) not connected / disabled"
    foreach ($d in ($down | Where-Object { $_.Status -eq 'Disabled' })) { Write-Warn "'$($d.Name)' is Disabled (use Restart network adapter to enable it)" }
    Write-Host ''
    Write-Header 'IP interface metrics (lowest metric = preferred route)'
    Write-Table (Get-NetIPInterface -AddressFamily IPv4 -ErrorAction SilentlyContinue | Sort-Object InterfaceMetric | Select-Object InterfaceAlias, InterfaceMetric, Dhcp, ConnectionState)
    $ok = $true
} catch {
    Write-Fail $_.Exception.Message
}
Complete-Action -Action $A -Success $ok

$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'PowerShell network adapter details'
Write-Header $A
$ok = $false
try {
    Write-Header 'Get-NetAdapter'
    Write-Table (Get-NetAdapter -ErrorAction Stop | Select-Object Name, InterfaceDescription, Status, LinkSpeed, MediaType, MacAddress, DriverVersionString)
    Write-Host ''
    Write-Header 'Get-NetIPAddress (IPv4)'
    Write-Table (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object InterfaceAlias, IPAddress, PrefixLength, PrefixOrigin, AddressState)
    Write-Host ''
    Write-Header 'Default routes'
    Write-Table (Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Select-Object InterfaceAlias, NextHop, RouteMetric, InterfaceMetric)
    Write-Host ''
    Write-Header 'DNS servers'
    Write-Table (Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.ServerAddresses } | Select-Object InterfaceAlias, @{ n = 'Servers'; e = { $_.ServerAddresses -join ', ' } })
    Write-Host ''
    Write-Header 'Adapter statistics (errors / discards)'
    Write-Table (Get-NetAdapterStatistics -ErrorAction SilentlyContinue | Select-Object Name, ReceivedBytes, SentBytes, ReceivedDiscardedPackets, OutboundDiscardedPackets, ReceivedPacketErrors, OutboundPacketErrors)
    Write-Host ''
    Write-Header 'Connection profiles'
    Write-Table (Get-NetConnectionProfile -ErrorAction SilentlyContinue | Select-Object Name, InterfaceAlias, NetworkCategory, IPv4Connectivity, IPv6Connectivity)
    $ok = $true
} catch {
    Write-Fail $_.Exception.Message
}
Complete-Action -Action $A -Success $ok

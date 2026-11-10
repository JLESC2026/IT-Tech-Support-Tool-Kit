. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
$A = 'Check printer ports'
Write-Header $A

function Test-TcpPort {
    param([string]$HostName, [int]$Port, [int]$TimeoutMs = 2000)
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $iar = $client.BeginConnect($HostName, $Port, $null, $null)
        if ($iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false) -and $client.Connected) {
            $client.EndConnect($iar)
            return $true
        }
        return $false
    } catch { return $false } finally { $client.Close() }
}

$printers = @(Get-CimInstance -ClassName Win32_Printer -ErrorAction SilentlyContinue)
$ports = @(Get-CimInstance -ClassName Win32_TCPIPPrinterPort -ErrorAction SilentlyContinue)
$bad = 0

if ($printers.Count -eq 0) { Write-Fail 'No printers installed'; $bad++ }

foreach ($p in ($printers | Sort-Object Name)) {
    $port = $ports | Where-Object { $_.Name -eq $p.PortName } | Select-Object -First 1
    if ($port) {
        $addr = $port.HostAddress
        $num = [int]$port.PortNumber
        $ping = $false
        try { $ping = Test-Connection -ComputerName $addr -Count 1 -Quiet -ErrorAction SilentlyContinue } catch { }
        $tcp = Test-TcpPort -HostName $addr -Port $num
        $line = "$($p.Name) -> $($p.PortName) ($addr : $num)  ping: $(if ($ping) { 'OK' } else { 'no reply' })  port: $(if ($tcp) { 'open' } else { 'closed/unreachable' })"
        if ($tcp) { Write-Ok $line } else { Write-Fail $line; $bad++ }
        if (-not $tcp) { Write-Info '    Check the printer is on, on the same network, and that its IP address has not changed.' }
    } else {
        $type = switch -Wildcard ($p.PortName) {
            'USB*'  { 'USB port' }
            'LPT*'  { 'Parallel port' }
            'WSD*'  { 'WSD (auto-discovered network printer)' }
            'IP_*'  { 'Standard TCP/IP port (details not found)' }
            'PORTPROMPT:' { 'No real port (virtual/PDF printer)' }
            'nul:'  { 'No real port' }
            'FILE:' { 'Print to file' }
            default { 'Other port type' }
        }
        Write-Info "$($p.Name) -> $($p.PortName)  [$type]"
        if ($p.PortName -like 'USB*' -and $p.WorkOffline) { Write-Warn '    USB printer is marked offline - check the cable and power.' }
    }
}
Complete-Action -Action $A -Success ($bad -eq 0) -Detail "$bad problem(s)"

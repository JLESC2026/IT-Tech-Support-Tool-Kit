param([string]$Target = '', [string]$Port = '')
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'Test-NetConnection'
Write-Header $A
if (-not $Target) {
    $Target = Read-InputBox -Prompt 'Host name or IP to test:' -Title 'Test-NetConnection' -Default 'www.microsoft.com'
    if (-not $Target) { Write-Info 'Cancelled.'; Exit-Toolkit -Code 0 }
    $Port = Read-InputBox -Prompt 'TCP port to test (for example 443, 80, 3389, 9100 for printers). Leave empty for ping only:' -Title 'Test-NetConnection' -Default '443'
    if ($null -eq $Port) { Write-Info 'Cancelled.'; Exit-Toolkit -Code 0 }
}
if (-not (Test-ValidHostName $Target)) {
    Write-Fail 'That is not a valid host name / IP address.'
    Complete-Action -Action $A -Success $false -Detail $Target
}
$ok = $false
try {
    if ($Port) {
        if ($Port -notmatch '^\d{1,5}$' -or [int]$Port -lt 1 -or [int]$Port -gt 65535) {
            Write-Fail 'The port must be a number from 1 to 65535.'
            Complete-Action -Action $A -Success $false -Detail "$Target`:$Port"
        }
        Write-Info "Testing TCP port $Port on $Target ..."
        $r = Test-NetConnection -ComputerName $Target -Port ([int]$Port) -InformationLevel Detailed -WarningAction SilentlyContinue
        $ok = [bool]$r.TcpTestSucceeded
        Write-Host (($r | Format-List ComputerName, RemoteAddress, RemotePort, InterfaceAlias, SourceAddress, PingSucceeded, TcpTestSucceeded | Out-String -Width 200).TrimEnd())
        if ($ok) { Write-Ok "Port $Port is open on $Target" } else { Write-Fail "Port $Port is closed, filtered or the host is unreachable" }
    } else {
        Write-Info "Pinging $Target ..."
        $r = Test-NetConnection -ComputerName $Target -InformationLevel Detailed -WarningAction SilentlyContinue
        $ok = [bool]$r.PingSucceeded
        Write-Host (($r | Format-List ComputerName, RemoteAddress, InterfaceAlias, SourceAddress, PingSucceeded, PingReplyDetails | Out-String -Width 200).TrimEnd())
        if ($ok) { Write-Ok "$Target answered the ping" } else { Write-Fail "$Target did not answer (it may block ping)" }
    }
} catch {
    Write-Fail $_.Exception.Message
}
Complete-Action -Action $A -Success $ok -Detail ("$Target $Port").Trim()

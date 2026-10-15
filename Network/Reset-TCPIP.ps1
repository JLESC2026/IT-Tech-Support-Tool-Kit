$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'Reset TCP/IP stack'
Write-Header $A
Assert-Admin $A
$ok = $false
try {
    $logDir = Join-Path $root 'Logs'
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    $logFile = Join-Path $logDir ("tcpip-reset-{0}.log" -f $env:COMPUTERNAME)

    Write-Info 'Resetting IPv4 (netsh int ip reset)...'
    $c1 = Invoke-Native -FilePath 'netsh.exe' -Arguments @('int', 'ip', 'reset', $logFile)
    $t1 = Get-LastNativeText
    Write-Info 'Resetting IPv6 (netsh int ipv6 reset)...'
    $c2 = Invoke-Native -FilePath 'netsh.exe' -Arguments @('int', 'ipv6', 'reset')

    if ($c1 -eq 0) {
        $ok = $true
    } elseif ($t1 -match 'Restart the computer') {
        $ok = $true
        Write-Warn 'Some entries could not be reset (access denied is common on newer Windows). The rest was reset.'
    } else {
        Write-Fail "netsh int ip reset returned code $c1"
    }
    if ($ok) { Write-Warn 'Restart the computer to finish the TCP/IP reset.' }
} catch {
    Write-Fail $_.Exception.Message
}
Complete-Action -Action $A -Success $ok -Detail 'Restart required'

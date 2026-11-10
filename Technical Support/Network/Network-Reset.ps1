$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'Full network reset'
Write-Header $A
Assert-Admin $A
Write-Warn 'Release IP, flush DNS, reset Winsock and TCP/IP. Static IP settings are kept. A restart is required afterwards.'
$ok = $true
try {
    $logDir = Join-Path $root 'Logs'
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    $logFile = Join-Path $logDir ("tcpip-reset-{0}.log" -f $env:COMPUTERNAME)

    Write-Header '1. Release / flush'
    [void](Invoke-Native -FilePath 'ipconfig.exe' -Arguments @('/release'))
    [void](Invoke-Native -FilePath 'ipconfig.exe' -Arguments @('/flushdns'))
    Write-Header '2. Renew'
    $c = Invoke-Native -FilePath 'ipconfig.exe' -Arguments @('/renew')
    if ($c -ne 0) { Write-Warn "ipconfig /renew returned $c" }
    Write-Header '3. Winsock'
    $c = Invoke-Native -FilePath 'netsh.exe' -Arguments @('winsock', 'reset')
    if ($c -ne 0) { Write-Fail "netsh winsock reset returned $c"; $ok = $false }
    Write-Header '4. TCP/IP'
    $c = Invoke-Native -FilePath 'netsh.exe' -Arguments @('int', 'ip', 'reset', $logFile)
    $txt = Get-LastNativeText
    if ($c -ne 0 -and $txt -notmatch 'Restart the computer') { Write-Fail "netsh int ip reset returned $c"; $ok = $false }
    [void](Invoke-Native -FilePath 'netsh.exe' -Arguments @('int', 'ipv6', 'reset') -Quiet)
    if ($ok) { Write-Warn 'Reset finished. RESTART THE COMPUTER now to apply it.' }
} catch {
    Write-Fail $_.Exception.Message
    $ok = $false
}
Complete-Action -Action $A -Success $ok -Detail 'Restart required'

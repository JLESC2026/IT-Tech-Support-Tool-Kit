param([string]$Target = '')
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'tracert'
Write-Header $A
if (-not $Target) {
    $Target = Read-InputBox -Prompt 'Host name or IP to trace the route to:' -Title 'tracert' -Default '8.8.8.8'
    if (-not $Target) { Write-Info 'Cancelled.'; Exit-Toolkit -Code 0 }
}
if (-not (Test-ValidHostName $Target)) {
    Write-Fail 'That is not a valid host name / IP address.'
    Complete-Action -Action $A -Success $false -Detail $Target
}
Write-Info "Tracing the route to $Target (max 30 hops, names not resolved so it runs faster) - this can take a minute..."
$code = Invoke-Native -FilePath 'tracert.exe' -Arguments @('-d', '-h', '30', '-w', '1500', $Target)
$txt = Get-LastNativeText
$ok = ($code -eq 0) -and ($txt -match 'Trace complete')
if (-not $ok -and $txt -match 'Unable to resolve') { Write-Fail 'The name could not be resolved - check DNS.' }
elseif (-not $ok) { Write-Warn 'The trace did not reach the target (a firewall may block it, or the path is broken).' }
Complete-Action -Action $A -Success $ok -Detail $Target

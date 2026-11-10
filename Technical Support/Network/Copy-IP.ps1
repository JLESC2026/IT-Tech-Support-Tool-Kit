$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'Copy IP address'
Write-Header $A
$ok = $false
$p = Get-PrimaryNetwork
if (-not $p -or $p.IPv4List.Count -eq 0) {
    Write-Fail 'No IPv4 address found on this computer.'
} else {
    $ip = [string]$p.IPv4List[0]
    Write-Info "Adapter: $($p.Adapter) ($($p.Type))"
    if (Copy-ToClipboard $ip) { Write-Ok "Copied to clipboard: $ip"; $ok = $true }
    else { Write-Fail "Could not use the clipboard. The address is: $ip" }
}
Complete-Action -Action $A -Success $ok

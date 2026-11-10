$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'Copy MAC address'
Write-Header $A
$ok = $false
$p = Get-PrimaryNetwork
if (-not $p -or -not $p.MAC) {
    Write-Fail 'No MAC address found (no active network adapter).'
} else {
    Write-Info "Adapter: $($p.Adapter) ($($p.Type))"
    if (Copy-ToClipboard $p.MAC) { Write-Ok "Copied to clipboard: $($p.MAC)"; $ok = $true }
    else { Write-Fail "Could not use the clipboard. The MAC address is: $($p.MAC)" }
}
Complete-Action -Action $A -Success $ok

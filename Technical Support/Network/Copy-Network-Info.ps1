$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'Copy complete network information'
Write-Header $A
$all = @(Get-NetworkSummary)
if ($all.Count -eq 0) {
    Write-Fail 'No active network adapters found.'
    Complete-Action -Action $A -Success $false
}
$text = Get-NetworkInfoText -Adapters $all
Write-Host $text
Write-Host ''
$ok = Copy-ToClipboard $text
if ($ok) { Write-Ok 'All of the above was copied to the clipboard' } else { Write-Fail 'Could not use the clipboard - select and copy the text above.' }
Complete-Action -Action $A -Success $ok

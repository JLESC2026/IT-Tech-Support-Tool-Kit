$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'Show network information'
Write-Header $A
Write-KV 'Computer name' $env:COMPUTERNAME
Write-KV 'Username' $env:USERNAME
Write-Host ''
$all = @(Get-NetworkSummary)
if ($all.Count -eq 0) {
    Write-Fail 'No active network adapters found.'
    Complete-Action -Action $A -Success $false
}
foreach ($n in $all) { Write-NetworkAdapterBlock $n }
Write-Info 'Tip: use "Copy complete network information" to paste all of this into a ticket.'
Complete-Action -Action $A -Success $true

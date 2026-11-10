param(
    [Parameter(Mandatory)][string]$Name,
    [string]$Label,
    [ValidateSet('Restart', 'Start', 'Stop')][string]$Action = 'Restart'
)
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
if (-not $Label) { $Label = $Name }
$A = "$Action service: $Label"
Write-Header $A
Assert-Admin $A
$ok = Invoke-ServiceGroup -Services @(@{ Name = $Name; Label = $Label }) -Mode $Action
Complete-Action -Action $A -Success $ok

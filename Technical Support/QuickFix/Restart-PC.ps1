param([int]$Delay = -1)
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
$A = 'Restart computer'
Write-Header $A
if ($Delay -lt 0) {
    $Delay = [int](Get-ToolkitSettings).restartDelaySeconds
    if ($Delay -lt 0) { $Delay = 30 }
}
Write-Warn "This computer will restart in $Delay seconds."
Write-Info 'To cancel, open a Command Prompt and run:  shutdown /a'
& shutdown.exe /r /t $Delay /c 'Restart requested by IT Technician Toolkit'
$ok = ($LASTEXITCODE -eq 0)
if (-not $ok) { Write-Fail "shutdown.exe returned code $LASTEXITCODE" }
Complete-Action -Action $A -Success $ok -Detail "Delay $Delay s"

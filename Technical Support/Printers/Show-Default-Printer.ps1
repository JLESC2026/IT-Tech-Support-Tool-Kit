. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
$A = 'Show default printer'
Write-Header $A
$def = Get-CimInstance -ClassName Win32_Printer -ErrorAction SilentlyContinue | Where-Object { $_.Default }
if ($def) {
    $def = @($def)[0]
    Write-Ok "Default printer: $($def.Name)"
    Write-Host "    Driver : $($def.DriverName)"
    Write-Host "    Port   : $($def.PortName)"
    Write-Host "    Status : $(Get-PrinterStatusText $def.PrinterStatus)"
    if ($def.WorkOffline) { Write-Warn 'The default printer is set to "Use Printer Offline"' }
    Write-Info 'Note: if Windows is set to "Let Windows manage my default printer", the default changes to the last printer used.'
} else {
    Write-Warn 'No default printer is set (or no printers are installed)'
}
Complete-Action -Action $A -Success ([bool]$def) -Detail $(if ($def) { $def.Name } else { 'none' })

. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
$A = 'Print test page (choose printer)'
Write-Header $A

$printers = @(Get-CimInstance -ClassName Win32_Printer -ErrorAction SilentlyContinue)
if ($printers.Count -eq 0) {
    Write-Fail 'No printers are installed'
    Complete-Action -Action $A -Success $false
}
$items = $printers | Sort-Object Name | ForEach-Object {
    [pscustomobject]@{
        Name    = $_.Name
        Default = $(if ($_.Default) { 'YES' } else { '' })
        Port    = $_.PortName
        Status  = Get-PrinterStatusText $_.PrinterStatus
    }
}
Write-Info 'A selection window has opened - choose a printer.'
$sel = @(Show-Picker -Items $items -Title 'Select a printer for the test page')
if ($sel.Count -eq 0) { Write-Info 'Nothing selected - cancelled.'; Exit-Toolkit -Code 0 }

& (Join-Path $PSScriptRoot 'Print-Test-Page.ps1') -Printer $sel[0].Name
exit $LASTEXITCODE

. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
$A = 'Printer preferences / maintenance'
Write-Header $A

$printers = @(Get-CimInstance -ClassName Win32_Printer -ErrorAction SilentlyContinue)
if ($printers.Count -eq 0) {
    Write-Fail 'No printers are installed'
    Complete-Action -Action $A -Success $false
}
$items = $printers | Sort-Object Name | ForEach-Object {
    [pscustomobject]@{ Name = $_.Name; Default = $(if ($_.Default) { 'YES' } else { '' }); Driver = $_.DriverName; Port = $_.PortName }
}
Write-Info 'A selection window has opened - choose a printer.'
$sel = @(Show-Picker -Items $items -Title 'Open preferences for which printer?')
if ($sel.Count -eq 0) { Write-Info 'Nothing selected - cancelled.'; Exit-Toolkit -Code 0 }

$name = $sel[0].Name
Start-Process -FilePath 'rundll32.exe' -ArgumentList "printui.dll,PrintUIEntry /e /n`"$name`""
Write-Ok "Opened printing preferences for '$name'"
Write-Info 'Head cleaning, nozzle check, ink charging and similar functions are NOT standard Windows features.'
Write-Info 'Look for a Maintenance / Utility tab in the window that just opened (Canon, Epson, Brother drivers have one).'
Write-Info 'If there is no such tab, use the vendor tool from the Manufacturer tools section.'
Complete-Action -Action $A -Success $true -Detail $name

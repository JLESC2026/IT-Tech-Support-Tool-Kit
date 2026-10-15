. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
$A = 'Check printer drivers'
Write-Header $A

$drivers = @(Get-PrinterDriver -ErrorAction SilentlyContinue)
$printers = @(Get-CimInstance -ClassName Win32_Printer -ErrorAction SilentlyContinue)

if ($drivers.Count -eq 0) {
    Write-Warn 'No printer drivers found (or the Print Spooler is not running)'
} else {
    Write-Info "$($drivers.Count) printer driver(s) installed:"
    Write-Table ($drivers | Sort-Object Name | ForEach-Object {
        [pscustomobject]@{
            Driver       = $_.Name
            Manufacturer = $_.Manufacturer
            Version      = $_.DriverVersion
            Environment  = $_.PrinterEnvironment
        }
    })
}

Write-Host ''
$missing = 0
$names = $drivers | ForEach-Object { $_.Name }
foreach ($p in ($printers | Sort-Object Name)) {
    if ($p.DriverName -and ($names -notcontains $p.DriverName)) {
        Write-Fail "$($p.Name): driver '$($p.DriverName)' is not installed"
        $missing++
    } else {
        Write-Ok "$($p.Name): driver '$($p.DriverName)'"
    }
}
if ($missing -gt 0) {
    Write-Info 'Fix: install the driver from the Manufacturer tools, or remove and re-add the printer.'
}
Complete-Action -Action $A -Success ($missing -eq 0) -Detail "$missing printer(s) with missing driver"

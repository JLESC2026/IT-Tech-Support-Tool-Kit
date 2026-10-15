$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'Driver information'
Write-Header $A
$issues = 0
try {
    Write-Info 'Reading installed drivers (this can take a few seconds)...'
    $drv = @(Get-CimInstance Win32_PnPSignedDriver -ErrorAction Stop | Where-Object { $_.DeviceName })
    Write-Info "$($drv.Count) devices with a driver"
    Write-Host ''

    Write-Header '1. Devices with driver problems'
    $bad = @(Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue | Where-Object { [int]$_.ConfigManagerErrorCode -notin 0, 45 })
    if ($bad.Count -eq 0) { Write-Ok 'None' }
    foreach ($b in $bad) { Write-Fail "$($b.Name): $(Get-DeviceProblemText $b.ConfigManagerErrorCode)"; $issues++ }
    Write-Host ''

    Write-Header '2. Unsigned drivers'
    $unsigned = @($drv | Where-Object { $_.IsSigned -eq $false })
    if ($unsigned.Count -eq 0) { Write-Ok 'None' }
    else {
        Write-Warn "$($unsigned.Count) unsigned driver(s):"
        Write-Table ($unsigned | Select-Object -First 20 DeviceName, Manufacturer, DriverVersion, DeviceClass)
        $issues++
    }
    Write-Host ''

    Write-Header '3. Key drivers (display, network, audio, Bluetooth, storage, chipset)'
    $classes = 'DISPLAY', 'NET', 'MEDIA', 'BLUETOOTH', 'SCSIADAPTER', 'HDC', 'SYSTEM'
    $key = @($drv | Where-Object { $classes -contains $_.DeviceClass -and $_.Manufacturer -and $_.Manufacturer -notmatch '^\(Standard' -and $_.Manufacturer -ne 'Microsoft' })
    Write-Table ($key | Sort-Object DeviceClass, DeviceName | Select-Object -First 40 @{ n = 'Class'; e = { $_.DeviceClass } }, @{ n = 'Device'; e = { $_.DeviceName } }, Manufacturer, DriverVersion, @{ n = 'Date'; e = { Format-Date $_.DriverDate } })
    Write-Host ''

    Write-Header '4. Oldest third-party drivers (possible update candidates)'
    $old = @($drv | Where-Object { $_.DriverDate -and $_.Manufacturer -ne 'Microsoft' -and $_.Manufacturer -notmatch '^\(Standard' } | Sort-Object DriverDate | Select-Object -First 12)
    Write-Table ($old | Select-Object @{ n = 'Device'; e = { $_.DeviceName } }, Manufacturer, DriverVersion, @{ n = 'Date'; e = { Format-Date $_.DriverDate } })
    $veryOld = @($old | Where-Object { ((Get-Date) - $_.DriverDate).TotalDays -gt 1825 })
    if ($veryOld.Count -gt 0) { Write-Warn "$($veryOld.Count) of these are older than 5 years - check the manufacturer site if the device misbehaves." }
} catch {
    Write-Fail $_.Exception.Message
    $issues++
}
Write-Host ''
if ($issues -eq 0) { Write-Ok 'No driver problems found' } else { Write-Warn "$issues item(s) need attention" }
Complete-Action -Action $A -Success ($issues -eq 0) -Detail "$issues item(s)"

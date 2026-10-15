. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
$A = 'Scanner diagnostics'
Write-Header $A
$issues = 0

Write-Host ''
Write-Header '1. WIA service'
$s = Get-Service -Name 'stisvc' -ErrorAction SilentlyContinue
if (-not $s) { Write-Fail 'WIA service not found'; $issues++ }
elseif ($s.Status -eq 'Running') { Write-Ok "Windows Image Acquisition: Running ($($s.StartType))" }
else { Write-Fail "Windows Image Acquisition: $($s.Status) ($($s.StartType))"; $issues++ }

Write-Host ''
Write-Header '2. Devices'
$devs = @(Get-CimInstance -ClassName Win32_PnPEntity -ErrorAction SilentlyContinue | Where-Object { $_.PNPClass -eq 'Image' })
if ($devs.Count -eq 0) { Write-Fail 'No imaging devices detected'; $issues++ }
foreach ($d in $devs) {
    $text = Get-DeviceProblemText $d.ConfigManagerErrorCode
    if ($d.ConfigManagerErrorCode -eq 0) { Write-Ok "$($d.Name): $text" } else { Write-Fail "$($d.Name): $text"; $issues++ }
}

Write-Host ''
Write-Header '3. Drivers'
$drv = @(Get-CimInstance -ClassName Win32_PnPSignedDriver -ErrorAction SilentlyContinue | Where-Object { $_.DeviceClass -eq 'IMAGE' })
if ($drv.Count -eq 0) { Write-Info 'No signed imaging drivers listed' }
else {
    Write-Table ($drv | ForEach-Object {
        [pscustomobject]@{
            Device       = $_.DeviceName
            Manufacturer = $_.Manufacturer
            Version      = $_.DriverVersion
            Date         = $(if ($_.DriverDate) { ([datetime]$_.DriverDate).ToString('yyyy-MM-dd') } else { '' })
        }
    })
}

Write-Host ''
Write-Header '4. WIA registered devices'
try {
    $mgr = New-Object -ComObject WIA.DeviceManager
    $count = 0
    foreach ($d in $mgr.DeviceInfos) {
        $count++
        Write-Ok "$($d.Properties.Item('Name').Value) (type $($d.Type))"
    }
    if ($count -eq 0) { Write-Warn 'WIA has no registered devices'; $issues++ }
} catch {
    Write-Warn "WIA could not be queried: $($_.Exception.Message)"
    $issues++
}

Write-Host ''
Write-Header 'Next steps'
Write-Info 'USB scanner: try another cable/port, then Restart WIA service, then reinstall the driver (Manufacturer tools).'
Write-Info 'Network scanner/MFP: check its IP address, that the PC can reach it (Check printer ports), and that the vendor scan software is allowed through the firewall.'
Write-Info 'Test with Windows Fax and Scan (Printer / Scanner section) to separate Windows problems from vendor software problems.'
Write-Host ''
if ($issues -eq 0) { Write-Ok 'No scanner issues detected' } else { Write-Warn "$issues issue(s) found - see messages above" }
Complete-Action -Action $A -Success ($issues -eq 0) -Detail "$issues issue(s)"

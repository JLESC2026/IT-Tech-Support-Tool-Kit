$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'Display / GPU information'
Write-Header $A
$issues = 0

function ConvertFrom-UInt16Array {
    param($Arr)
    if (-not $Arr) { return '' }
    return ((@($Arr) | Where-Object { $_ -ne 0 } | ForEach-Object { [string][char]$_ }) -join '')
}

try {
    Write-Header '1. Graphics adapters'
    $gpus = @(Get-CimInstance Win32_VideoController -ErrorAction Stop)
    if ($gpus.Count -eq 0) { Write-Fail 'No graphics adapter found'; $issues++ }
    foreach ($g in $gpus) {
        Write-KV 'Adapter' $g.Name
        Write-KV 'Driver version' $g.DriverVersion
        Write-KV 'Driver date' (Format-Date $g.DriverDate)
        if ($g.CurrentHorizontalResolution) { Write-KV 'Resolution' "$($g.CurrentHorizontalResolution) x $($g.CurrentVerticalResolution) @ $($g.CurrentRefreshRate) Hz" }
        Write-KV 'Status' $g.Status
        if ([int]$g.ConfigManagerErrorCode -ne 0) { Write-Fail "  $(Get-DeviceProblemText $g.ConfigManagerErrorCode)"; $issues++ }
        if ($g.Name -match 'Basic Display|Basic Render') {
            Write-Warn '  Microsoft Basic Display Adapter = no real GPU driver installed. Install the NVIDIA / AMD / Intel driver from the manufacturer.'
            $issues++
        }
        if ($g.DriverDate -and ((Get-Date) - $g.DriverDate).TotalDays -gt 1095) { Write-Info '  Driver is older than 3 years.' }
        Write-Host ''
    }

    Write-Header '2. Connected monitors'
    $mons = @(Get-CimInstance -Namespace 'root\wmi' -ClassName WmiMonitorID -ErrorAction SilentlyContinue)
    if ($mons.Count -eq 0) { Write-Info 'No monitor information available' }
    foreach ($m in $mons) {
        $maker = ConvertFrom-UInt16Array $m.ManufacturerName
        $model = ConvertFrom-UInt16Array $m.UserFriendlyName
        $serial = ConvertFrom-UInt16Array $m.SerialNumberID
        Write-Ok "$maker $model   serial: $serial   made: week $($m.WeekOfManufacture) / $($m.YearOfManufacture)"
    }
    Write-Host ''
    Write-Info 'Flicker or no signal: try another cable/port, reset the GPU driver with Win+Ctrl+Shift+B, then update the driver.'
} catch {
    Write-Fail $_.Exception.Message
    $issues++
}
Write-Host ''
if ($issues -eq 0) { Write-Ok 'No display problems found' } else { Write-Warn "$issues issue(s) found" }
Complete-Action -Action $A -Success ($issues -eq 0) -Detail "$issues issue(s)"

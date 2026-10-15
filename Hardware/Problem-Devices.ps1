$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'Problem devices (Device Manager errors)'
Write-Header $A
$count = 0
try {
    $bad = @(Get-CimInstance Win32_PnPEntity -ErrorAction Stop | Where-Object { [int]$_.ConfigManagerErrorCode -ne 0 })
    # Code 45 = not currently connected (ghost devices) - not a real problem
    $real = @($bad | Where-Object { [int]$_.ConfigManagerErrorCode -ne 45 })
    $count = $real.Count
    if ($count -eq 0) {
        Write-Ok 'No devices with problems'
    } else {
        Write-Warn "$count device(s) have a problem:"
        Write-Host ''
        foreach ($d in ($real | Sort-Object PNPClass, Name)) {
            $code = [int]$d.ConfigManagerErrorCode
            $name = $d.Name
            if (-not $name) { $name = '(unnamed device)' }
            Write-Fail "$name   [$($d.PNPClass)]"
            Write-Host "       $(Get-DeviceProblemText $code)"
            Write-Host "       ID: $($d.PNPDeviceID)"
            switch ($code) {
                22 { Write-Info '       Fix: Device Manager > right-click > Enable device.' }
                { $_ -in 28, 1, 3, 18, 31, 37, 39 } { Write-Info '       Fix: install/update the driver from the manufacturer (or use Update driver > Search automatically).' }
                43 { Write-Info '       Fix: unplug and re-plug, try another port/cable; if built-in, update or reinstall its driver.' }
                10 { Write-Info '       Fix: update the driver or reinstall the device; restart the PC.' }
            }
            Write-Host ''
        }
    }
} catch {
    Write-Fail $_.Exception.Message
    $count = 1
}
Complete-Action -Action $A -Success ($count -eq 0) -Detail "$count problem device(s)"

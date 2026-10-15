. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
$A = 'Remove and re-detect printer'
Write-Header $A
Assert-Admin $A

$printers = @(Get-Printer -ErrorAction SilentlyContinue)
if ($printers.Count -eq 0) {
    Write-Fail 'No printers are installed'
    Complete-Action -Action $A -Success $false
}
$items = $printers | Sort-Object Name | ForEach-Object {
    [pscustomobject]@{ Name = $_.Name; Driver = $_.DriverName; Port = $_.PortName; Shared = $_.Shared }
}
Write-Info 'A selection window has opened - choose the printer to remove.'
$sel = @(Show-Picker -Items $items -Title 'Select the printer to remove and re-detect')
if ($sel.Count -eq 0) { Write-Info 'Nothing selected - cancelled.'; Exit-Toolkit -Code 0 }

$name = $sel[0].Name
$driver = $sel[0].Driver
$port = $sel[0].Port
Write-Info "Selected: $name (driver: $driver, port: $port)"
if (-not (Confirm-Action -Message "Remove the printer '$name' from this computer?`n`nThe toolkit will then rescan for devices and re-add it if it does not come back by itself." -Title 'Remove printer')) {
    Write-Info 'Cancelled - nothing was removed.'
    Exit-Toolkit -Code 0
}

$ok = $false
try {
    Remove-Printer -Name $name -ErrorAction Stop
    Write-Ok "Removed printer '$name'"

    Write-Info 'Restarting Print Spooler...'
    [void](Restart-ServiceByName -Name 'Spooler' -Label 'Print Spooler')

    Write-Info 'Scanning for hardware changes...'
    & pnputil.exe /scan-devices | Out-Null
    Start-Sleep -Seconds 6

    if (Get-Printer -Name $name -ErrorAction SilentlyContinue) {
        Write-Ok "Windows re-detected '$name' automatically"
        $ok = $true
    } else {
        $driverOk = [bool](Get-PrinterDriver -Name $driver -ErrorAction SilentlyContinue)
        $portOk = [bool](Get-PrinterPort -Name $port -ErrorAction SilentlyContinue)
        if ($driverOk -and $portOk) {
            Write-Info 'Not re-detected - re-adding with the same driver and port...'
            Add-Printer -Name $name -DriverName $driver -PortName $port -ErrorAction Stop
            Write-Ok "Re-added '$name' ($driver on $port)"
            $ok = $true
        } else {
            Write-Warn 'Could not re-add automatically (driver or port no longer exists).'
            Write-Info 'Reconnect the USB cable or use Settings > Printers & scanners > Add device. Driver installers can go in the Manufacturer folder.'
        }
    }
} catch {
    Write-Fail $_.Exception.Message
}
Complete-Action -Action $A -Success $ok -Detail "$name ($driver / $port)"

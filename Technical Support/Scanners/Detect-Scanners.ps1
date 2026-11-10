. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
$A = 'Detect scanners'
Write-Header $A

$wia = Get-Service -Name 'stisvc' -ErrorAction SilentlyContinue
if ($wia -and $wia.Status -eq 'Running') { Write-Ok 'Windows Image Acquisition (WIA) service is running' }
elseif ($wia) { Write-Warn "WIA service is $($wia.Status) - scanners may not be listed. Use 'Restart WIA service'." }
else { Write-Warn 'WIA service not found on this PC' }

$found = 0

Write-Host ''
Write-Info 'Imaging devices from Device Manager (Plug and Play):'
$pnp = @(Get-PnpDevice -Class 'Image' -ErrorAction SilentlyContinue)
if ($pnp.Count -eq 0) {
    Write-Host '    (none)'
} else {
    $found += $pnp.Count
    Write-Table ($pnp | Sort-Object FriendlyName | ForEach-Object {
        [pscustomobject]@{ Device = $_.FriendlyName; Status = $_.Status; Present = $_.Present }
    })
}

Write-Host ''
Write-Info 'Devices registered with WIA:'
try {
    $mgr = New-Object -ComObject WIA.DeviceManager
    $rows = @()
    foreach ($d in $mgr.DeviceInfos) {
        $type = switch ([int]$d.Type) { 1 { 'Scanner' } 2 { 'Camera' } 3 { 'Video' } default { 'Other' } }
        $name = $d.Properties.Item('Name').Value
        $rows += [pscustomobject]@{ Name = $name; Type = $type; DeviceId = $d.DeviceID }
    }
    if ($rows.Count -eq 0) { Write-Host '    (none)' }
    else { $found += @($rows | Where-Object { $_.Type -eq 'Scanner' }).Count; Write-Table $rows }
} catch {
    Write-Warn "WIA could not be queried: $($_.Exception.Message)"
}

Write-Host ''
if ($found -eq 0) {
    Write-Fail 'No scanners detected'
    Write-Info 'Check: cable/power, USB port, or for network scanners that the PC and scanner are on the same network. Then try Restart WIA service.'
} else {
    Write-Ok 'Scanner / imaging device(s) detected'
}
Complete-Action -Action $A -Success ($found -gt 0) -Detail "$found device(s)"

param([string]$Name = '')
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'Restart network adapter'
Write-Header $A
Assert-Admin $A
$ok = $false
try {
    if (-not $Name) {
        $items = @(Get-NetAdapter -ErrorAction Stop | Sort-Object Status, Name | ForEach-Object {
            [pscustomobject]@{ Name = $_.Name; Description = $_.InterfaceDescription; Status = [string]$_.Status; Speed = [string]$_.LinkSpeed; MAC = [string]$_.MacAddress }
        })
        if ($items.Count -eq 0) { Write-Fail 'No network adapters found.'; Complete-Action -Action $A -Success $false }
        Write-Info 'A selection window has opened - choose the adapter to restart.'
        $sel = @(Show-Picker -Items $items -Title 'Restart which network adapter?')
        if ($sel.Count -eq 0) { Write-Info 'Nothing selected - cancelled.'; Exit-Toolkit -Code 0 }
        $Name = $sel[0].Name
    }
    Write-Info "Restarting adapter '$Name' - the connection drops briefly..."
    Restart-NetAdapter -Name $Name -Confirm:$false -ErrorAction Stop
    $up = $false
    for ($i = 0; $i -lt 15; $i++) {
        Start-Sleep -Seconds 2
        $st = (Get-NetAdapter -Name $Name -ErrorAction SilentlyContinue).Status
        if ($st -eq 'Up') { $up = $true; break }
    }
    if ($up) {
        Write-Ok "Adapter '$Name' is Up"
        $ok = $true
        Start-Sleep -Seconds 3
        $n = @(Get-NetworkSummary | Where-Object { $_.Adapter -eq $Name } | Select-Object -First 1)
        if ($n.Count -gt 0 -and $n[0].IPv4) { Write-Info "Address: $($n[0].IPv4)" } else { Write-Warn 'No IPv4 address yet - wait a few seconds or use Renew IP.' }
    } else {
        Write-Fail "Adapter '$Name' did not come back Up (no cable, Wi-Fi off, or disabled in BIOS?)"
    }
} catch {
    Write-Fail $_.Exception.Message
}
Complete-Action -Action $A -Success $ok -Detail $Name

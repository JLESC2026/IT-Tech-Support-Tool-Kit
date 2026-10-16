# Network diagnostics - adapters, Wi-Fi, gateway / DNS / internet tests and a diagnosis.
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
. (Join-Path $root 'Launcher\Part4-Helpers.ps1')
$A = 'Network diagnostics'
Write-Header $A
$ok = $false
try {
    Write-Header '1. Active adapters'
    $all = @(Get-NetworkSummary)
    if ($all.Count -eq 0) { Write-Fail 'No active network adapters found (cable unplugged, Wi-Fi off, or adapter disabled).' }
    foreach ($n in $all) { Write-NetworkAdapterBlock $n }

    Write-Header '2. Connectivity tests (gateway, DNS, internet)'
    $res = Invoke-InternetTest
    Write-ResultLines $res.Lines
    $ok = [bool]$res.Success
    Write-Host ''

    Write-Header '3. Firewall profiles'
    try {
        Write-Table (Get-NetFirewallProfile -ErrorAction Stop | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction)
    } catch { Write-Info 'Firewall profile information is not available.' }
    Write-Host ''

    Write-Header '4. Network services'
    foreach ($svc in 'Dhcp', 'Dnscache', 'Netman', 'WlanSvc', 'NlaSvc') {
        $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if (-not $s) { Write-Info "$svc : not installed (normal for WlanSvc on PCs without Wi-Fi)" }
        elseif ($s.Status -eq 'Running') { Write-Ok "$($s.DisplayName): Running" }
        else { Write-Warn "$($s.DisplayName): $($s.Status) ($($s.StartType))" }
    }
} catch {
    Write-Fail $_.Exception.Message
}
Complete-Action -Action $A -Success $ok -Detail $res.Diagnosis

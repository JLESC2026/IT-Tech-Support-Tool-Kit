# Firewall diagnostics (read-only) - nothing is changed.
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'Firewall diagnostics'
Write-Header $A
$issues = 0
try {
    Write-Header '1. Windows Defender Firewall service'
    foreach ($n in 'mpssvc', 'BFE') {
        $s = Get-Service -Name $n -ErrorAction SilentlyContinue
        if (-not $s) { Write-Warn "$n : not found" }
        elseif ($s.Status -eq 'Running') { Write-Ok "$($s.DisplayName): Running" }
        else { Write-Fail "$($s.DisplayName): $($s.Status)"; $issues++ }
    }
    Write-Host ''

    Write-Header '2. Profiles'
    $profiles = @(Get-NetFirewallProfile -ErrorAction Stop)
    foreach ($p in $profiles) {
        $line = "{0}: enabled={1}  inbound default={2}  outbound default={3}" -f $p.Name, $p.Enabled, $p.DefaultInboundAction, $p.DefaultOutboundAction
        if ($p.Enabled -eq $false -or [string]$p.Enabled -eq 'False') { Write-Warn "$line  (firewall is OFF for this profile)" } else { Write-Ok $line }
        if ([string]$p.DefaultOutboundAction -eq 'Block') { Write-Warn "$($p.Name): outbound traffic is blocked by default"; $issues++ }
    }
    Write-Host ''

    Write-Header '3. Active network profile'
    try {
        Write-Table (Get-NetConnectionProfile -ErrorAction Stop | Select-Object Name, InterfaceAlias, NetworkCategory, IPv4Connectivity)
        Write-Info 'Public network = strictest rules; sharing and printing often need a Private network.'
    } catch { Write-Info 'Network profile information is not available.' }
    Write-Host ''

    Write-Header '4. Other security products registered with Windows'
    try {
        $fw = @(Get-CimInstance -Namespace 'root\SecurityCenter2' -ClassName FirewallProduct -ErrorAction Stop)
        if ($fw.Count -eq 0) { Write-Info 'No third-party firewall registered' }
        foreach ($f in $fw) { Write-Info "Firewall product: $($f.displayName)" }
    } catch { Write-Info 'Security Center information is not available (normal on Windows Server).' }
    Write-Host ''

    Write-Header '5. Rules that matter for printing, sharing and discovery'
    foreach ($g in 'File and Printer Sharing', 'Network Discovery', 'Core Networking') {
        $rules = @(Get-NetFirewallRule -DisplayGroup $g -ErrorAction SilentlyContinue)
        if ($rules.Count -eq 0) { Write-Info "${g}: no rules found"; continue }
        $on = @($rules | Where-Object { [string]$_.Enabled -eq 'True' }).Count
        Write-Info "${g}: $on of $($rules.Count) rules enabled"
    }
    Write-Host ''

    Write-Header '6. Enabled inbound BLOCK rules (first 20)'
    $blocks = @(Get-NetFirewallRule -Direction Inbound -Action Block -Enabled True -ErrorAction SilentlyContinue | Select-Object -First 20)
    if ($blocks.Count -eq 0) { Write-Ok 'No custom inbound block rules' }
    else { Write-Table ($blocks | Select-Object DisplayName, Profile, Group); Write-Info 'Block rules override allow rules. Check these if a program cannot be reached.' }
    Write-Host ''
    Write-Info 'To change rules open "Windows Defender Firewall with Advanced Security" (Advanced > System).'
} catch {
    Write-Fail $_.Exception.Message
    $issues++
}
Write-Host ''
if ($issues -eq 0) { Write-Ok 'No firewall problems detected' } else { Write-Warn "$issues item(s) need attention" }
Complete-Action -Action $A -Success ($issues -eq 0) -Detail "$issues item(s)"
